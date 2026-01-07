{ pkgs ? import <nixpkgs> {} }:

(pkgs.haskellPackages.callCabal2nix "liquid-haskell-app" ./liquid-haskell-app {}).overrideAttrs (old: {
  nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ pkgs.z3 ];
})
