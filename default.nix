{ pkgs ? import <nixpkgs> {} }:

pkgs.haskell.lib.overrideCabal (pkgs.haskellPackages.callCabal2nix "liquid-haskell-app" ./liquid-haskell-app {}) (old: {
  buildTools = (old.buildTools or []) ++ [ pkgs.z3 ];
  doHaddock = false;
})
