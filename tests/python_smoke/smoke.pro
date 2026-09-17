// Smallest problem that reaches F_Python: one triangle, one system, no solve.
// Exercises BOTH forms of the Python function, because they fail independently:
//   - the inline-expression form goes through PyRun_SimpleString
//   - the .py-file form goes through PyRun_SimpleFile(FILE*, ...), which is the
//     one that segfaults when getdp and python310.dll are on different C runtimes
// Both must print 42.
Group { Dom = Region[1]; }
Function {
  pyexpr[] = Python[2.0, 40.0]{"output=[input[0].real+input[1].real]"};
  pyfile[] = Python[2.0, 40.0]{"smoke.py"};
}
Jacobian { { Name J; Case { { Region All; Jacobian Vol; } } } }
Integration {
  { Name I; Case { { Type Gauss;
      Case { { GeoElement Triangle; NumberOfPoints 3; } } } } }
}
FunctionSpace {
  { Name S; Type Form0;
    BasisFunction {
      { Name sn; NameOfCoef un; Function BF_Node; Support Dom; Entity NodesOf[All]; }
    }
  }
}
Formulation {
  { Name F; Type FemEquation;
    Quantity { { Name u; Type Local; NameOfSpace S; } }
    Equation { Galerkin { [ Dof{d u} , {d u} ]; In Dom; Jacobian J; Integration I; } }
  }
}
Resolution {
  { Name smoke;
    System { { Name A; NameOfFormulation F; } }
    Operation {
      Evaluate[ $a = pyexpr[] ];
      Print[ {$a}, Format "PYSMOKE expr %g" ];
      Evaluate[ $b = pyfile[] ];
      Print[ {$b}, Format "PYSMOKE file %g" ];
    }
  }
}
