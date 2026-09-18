// Host-only unit test for the CPU-side half of LinAlg_CUDSS.cpp: the
// upper-triangle map that lets a complex symmetric matrix be sent to cuDSS as
// half a matrix, and the per-solve check that the two triangles still agree.
//
// Those two decide whether the GPU is handed a correct problem, and they are
// pure host code - no device, no driver, no cuDSS call. So they are tested
// here, on any machine, rather than only on the one box with an NVIDIA card.
// The file under test is #included (not linked) so the test can reach the
// helpers in its anonymous namespace and drive the retained context directly.
//
// Run it with scripts/test_cudss_host.sh.

#include "LinAlg_CUDSS.cpp" // NOLINT - deliberate: see above

#include <cstdio>
#include <string>
#include <vector>

namespace {

int failures = 0;
int checks = 0;

void check(bool ok, const std::string &what)
{
  checks++;
  if(!ok) {
    failures++;
    fprintf(stderr, "  FAIL: %s\n", what.c_str());
  }
}

template <typename T>
void checkEqual(const std::vector<T> &got, const std::vector<T> &want,
                const std::string &what)
{
  checks++;
  if(got == want) return;
  failures++;
  fprintf(stderr, "  FAIL: %s\n         got :", what.c_str());
  for(size_t i = 0; i < got.size(); i++) fprintf(stderr, " %d", (int)got[i]);
  fprintf(stderr, "\n         want:");
  for(size_t i = 0; i < want.size(); i++) fprintf(stderr, " %d", (int)want[i]);
  fprintf(stderr, "\n");
}

// The reference system, 4x4, structurally symmetric with a full diagonal:
//
//     x . x .        CSR index of each stored entry:
//     . x . x          row 0: 0:(0,0) 1:(0,2)
//     x . x x          row 1: 2:(1,1) 3:(1,3)
//     . x x x          row 2: 4:(2,0) 5:(2,2) 6:(2,3)
//                      row 3: 7:(3,1) 8:(3,2) 9:(3,3)
//
// Mirror pairs are therefore 1<->4, 3<->7, 6<->8.
struct Matrix {
  std::vector<int> rowPtr, colInd;
  std::vector<double> values; // interleaved (re,im)
};

Matrix reference()
{
  Matrix m;
  m.rowPtr = {0, 2, 4, 7, 10};
  m.colInd = {0, 2, 1, 3, 0, 2, 3, 1, 2, 3};
  m.values = {
    10, 1, //  0 (0,0)
    2,  -3, //  1 (0,2)
    20, 2, //  2 (1,1)
    4,  5, //  3 (1,3)
    2,  -3, //  4 (2,0)  mirrors 1
    30, 3, //  5 (2,2)
    6,  -7, //  6 (2,3)
    4,  5, //  7 (3,1)  mirrors 3
    6,  -7, //  8 (3,2)  mirrors 6
    40, 4, //  9 (3,3)
  };
  return m;
}

// Drives buildUpperPattern() on a matrix and hands back what it produced.
struct Upper {
  bool ok;
  std::vector<int> uRowPtr, uColInd, gather, mirror;
};

Upper analyse(const Matrix &m)
{
  Upper u;
  const int n = (int)m.rowPtr.size() - 1;
  const int nnz = (int)m.colInd.size();
  u.ok = buildUpperPattern(n, nnz, m.rowPtr.data(), m.colInd.data(), u.uRowPtr,
                           u.uColInd, u.gather, u.mirror);
  return u;
}

// Loads a context with an already-analysed pattern, the way buildContext()
// would, so stageSymmetricValues() can be exercised on its own.
void loadContext(const Upper &u)
{
  ctx = Context();
  ctx.symmetric = true;
  ctx.upNnz = (int)u.gather.size();
  ctx.gather = u.gather;
  ctx.mirror = u.mirror;
  ctx.stage.assign(2 * (size_t)ctx.upNnz, 0.0);
}

void testSymmetricPattern()
{
  fprintf(stderr, "structurally symmetric matrix\n");
  const Matrix m = reference();
  const Upper u = analyse(m);

  check(u.ok, "accepted as symmetric");
  if(!u.ok) return;

  checkEqual(u.uRowPtr, {0, 2, 4, 6, 7}, "upper row offsets");
  checkEqual(u.uColInd, {0, 2, 1, 3, 2, 3, 3}, "upper column indices");
  checkEqual(u.gather, {0, 1, 2, 3, 5, 6, 9}, "gather map into the full CSR");
  checkEqual(u.mirror, {-1, 4, -1, 7, -1, 8, -1}, "transposed-entry map");

  // What cuDSS requires of the triangle it is given: offsets non-decreasing and
  // ending at the entry count, columns ascending within a row, diagonal first.
  bool shapeOk = (u.uRowPtr.front() == 0) &&
                 (u.uRowPtr.back() == (int)u.uColInd.size());
  for(size_t i = 0; i + 1 < u.uRowPtr.size(); i++) {
    if(u.uRowPtr[i + 1] < u.uRowPtr[i]) shapeOk = false;
    if(u.uRowPtr[i + 1] == u.uRowPtr[i]) continue; // empty row: no diagonal
    if(u.uColInd[u.uRowPtr[i]] != (int)i) shapeOk = false; // diagonal first
    for(int k = u.uRowPtr[i] + 1; k < u.uRowPtr[i + 1]; k++)
      if(u.uColInd[k] <= u.uColInd[k - 1]) shapeOk = false;
  }
  check(shapeOk, "upper CSR is well formed (sorted, diagonal present)");
}

void testValueStaging()
{
  fprintf(stderr, "value gathering\n");
  const Matrix m = reference();
  const Upper u = analyse(m);
  loadContext(u);

  check(stageSymmetricValues(m.values.data()), "symmetric values accepted");
  const std::vector<double> want = {10, 1, 2, -3, 20, 2, 4, 5, 30, 3, 6, -7, 40, 4};
  checkEqual(ctx.stage, want, "staged upper-triangle values");
}

void testNumericAsymmetry()
{
  fprintf(stderr, "numeric asymmetry\n");
  const Matrix m = reference();
  const Upper u = analyse(m);
  loadContext(u);

  // A real difference between a_ij and a_ji: must be caught here, before a
  // factorization is spent on half a matrix that does not describe the whole.
  Matrix broken = m;
  broken.values[2 * 4] = 2.5; // was 2, mirrors entry 1
  check(!stageSymmetricValues(broken.values.data()),
        "a 25% difference is rejected");

  // Assembly adds contributions in a different order for (i,j) and (j,i), so
  // the two can differ in the last bits. That must NOT be called asymmetric.
  Matrix dust = m;
  dust.values[2 * 4] = 2.0 + 1e-13;
  check(stageSymmetricValues(dust.values.data()),
        "rounding-level difference is accepted");

  // ... but a difference far above the noise floor still is asymmetric, even
  // though it is small in absolute terms.
  Matrix small = m;
  small.values[2 * 4] = 2.0 + 1e-6;
  check(!stageSymmetricValues(small.values.data()),
        "1e-6 against entries of size 2 is rejected");
}

void testRejectedPatterns()
{
  fprintf(stderr, "patterns that cannot use the symmetric path\n");

  // No diagonal in row 1. cuDSS wants the diagonal inside the triangle.
  {
    Matrix m = reference();
    m.rowPtr = {0, 2, 3, 6, 9};
    m.colInd = {0, 2, 3, 0, 2, 3, 1, 2, 3};
    m.values.resize(2 * m.colInd.size(), 1.0);
    check(!analyse(m).ok, "row without a diagonal is rejected");
  }

  // (0,2) is stored but (2,0) is not: nothing to mirror.
  {
    Matrix m = reference();
    m.rowPtr = {0, 2, 4, 6, 9};
    m.colInd = {0, 2, 1, 3, 2, 3, 1, 2, 3};
    m.values.resize(2 * m.colInd.size(), 1.0);
    check(!analyse(m).ok, "missing transposed entry is rejected");
  }

  // The mirror image: an entry below the diagonal, (3,0), whose partner (0,3)
  // is absent. Nothing in the upper triangle ever looks for it, so only the
  // closing count catches it - the case that check exists for.
  {
    Matrix m = reference();
    m.rowPtr = {0, 2, 4, 7, 11};
    m.colInd = {0, 2, 1, 3, 0, 2, 3, 0, 1, 2, 3};
    m.values.resize(2 * m.colInd.size(), 1.0);
    check(!analyse(m).ok, "unmatched lower entry is rejected");
  }
}

void testPatternReuse()
{
  fprintf(stderr, "context reuse\n");
  const Matrix m = reference();
  const int n = (int)m.rowPtr.size() - 1;
  const int nnz = (int)m.colInd.size();

  ctx = Context();
  check(!patternMatches(n, nnz, m.rowPtr.data(), m.colInd.data()),
        "an empty context never matches");

  ctx.valid = true;
  ctx.n = n;
  ctx.nnz = nnz;
  ctx.rowPtr = m.rowPtr;
  ctx.colInd = m.colInd;
  check(patternMatches(n, nnz, m.rowPtr.data(), m.colInd.data()),
        "the same pattern is reused");

  // Same n and nnz, one column moved: the analysis from the previous system
  // would be wrong for this one.
  {
    std::vector<int> colInd = m.colInd;
    colInd[6] = 1;
    check(!patternMatches(n, nnz, m.rowPtr.data(), colInd.data()),
          "a moved column index is not reused");
  }
  {
    std::vector<int> rowPtr = m.rowPtr;
    rowPtr[2] = 3;
    check(!patternMatches(n, nnz, rowPtr.data(), m.colInd.data()),
          "a changed row offset is not reused");
  }
  check(!patternMatches(n - 1, nnz, m.rowPtr.data(), m.colInd.data()),
        "a different size is not reused");

  // destroyContext() on a context that never reached the device must not touch
  // CUDA (every pointer is null) and must leave nothing behind.
  destroyContext();
  check(!ctx.valid && ctx.n == 0 && ctx.rowPtr.empty(),
        "destroyContext resets the retained state");
}

} // namespace

int main()
{
  testSymmetricPattern();
  testValueStaging();
  testNumericAsymmetry();
  testRejectedPatterns();
  testPatternReuse();

  if(failures) {
    fprintf(stderr, "\ncudss_host: FAIL (%d of %d checks)\n", failures, checks);
    return 1;
  }
  fprintf(stderr, "\ncudss_host: OK (%d checks)\n", checks);
  return 0;
}
