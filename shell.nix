with { pkgs = import <nixpkgs> {}; ghc-utils = import ../ghc-utils {}; };
pkgs.mkShell
  { buildInputs = [ pkgs.haskell.compiler.ghc883 pkgs.zlib pkgs.haskellPackages.cabal-install pkgs.numactl pkgs.binutils-unwrapped pkgs.lazygit pkgs.valgrind pkgs.gperftools pkgs.numactl ghc-utils ];
    shellHook=''export LD_LIBRARY_PATH=${pkgs.gmp}/lib:${pkgs.zlib}/lib:${pkgs.ncurses}/lib:${pkgs.numactl}/lib:${pkgs.gperftools}/lib'';
  }
