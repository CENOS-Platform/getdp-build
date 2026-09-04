/* MKL's Windows ScaLAPACK exports Fortran names as UPPERCASE without a
 * trailing underscore; PETSc's matscalapack.c (gfortran conventions) wants
 * pzelset_ / pzelget_ / pzmatadd_. Only these three are missing, and only
 * PETSc's MATSCALAPACK type uses them - GetDP never does. Pass-through is
 * ABI-correct: Fortran passes by reference and both compilers append hidden
 * character lengths last.
 */
#include <stddef.h>

extern void PZELSET(void *a, void *ia, void *ja, void *desca, void *alpha);
extern void PZELGET(char *scope, char *top, void *alpha, void *a, void *ia,
                    void *ja, void *desca, size_t l_scope, size_t l_top);
extern void PZMATADD(void *m, void *n, void *alpha, void *a, void *ia, void *ja,
                     void *desca, void *beta, void *c, void *ic, void *jc,
                     void *descc);

void pzelset_(void *a, void *ia, void *ja, void *desca, void *alpha)
{
  PZELSET(a, ia, ja, desca, alpha);
}

void pzelget_(char *scope, char *top, void *alpha, void *a, void *ia, void *ja,
              void *desca, size_t l_scope, size_t l_top)
{
  PZELGET(scope, top, alpha, a, ia, ja, desca, l_scope, l_top);
}

void pzmatadd_(void *m, void *n, void *alpha, void *a, void *ia, void *ja,
               void *desca, void *beta, void *c, void *ic, void *jc, void *descc)
{
  PZMATADD(m, n, alpha, a, ia, ja, desca, beta, c, ic, jc, descc);
}
