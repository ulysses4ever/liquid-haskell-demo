{
  description = "FM";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-25.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
        "aarch64-linux"
      ];
      perSystem =
        { system, self', ... }:
        let
          # Pin GHC version for easier, explicit upgrades later
          ghcVersion = "9122";
          pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [
              (
                final: prev:
                let
                  hlib = final.haskell.lib.compose;
                in
                {
                  haskellPackages = prev.haskell.packages."ghc${ghcVersion}".override (old: {
                    # https://niteria.github.io/posts/nix-notes-overriding-haskell-packages/
                    all-cabal-hashes = pkgs.fetchurl {
                      url = "https://github.com/commercialhaskell/all-cabal-hashes/archive/8ac76f327d5861499e4ebe357ec7159222bffdd9.tar.gz";
                      sha256 = "039rz01rv7wll50xbllifkkw4vl087awh446zkif27kv1738nrc8";
                    };
                    overrides = final.lib.composeExtensions (old.overrides or (_: _: { })) (
                      hfinal: hprev: {
                        # tasty dependency version has unsupported version
                        smtlib-backends-tests = hlib.dontCheck (hlib.unmarkBroken hprev.smtlib-backends-tests);
                        smtlib-backends-process = hlib.dontCheck (hlib.unmarkBroken hprev.smtlib-backends-process);

                        # 0.7.20, wants 0.7.18
                        store = hlib.dontCheck hprev.store;

                        liquid-fixpoint = hlib.unmarkBroken hprev.liquid-fixpoint;
                        cabal2nix = hlib.dontCheck hprev.cabal2nix;
                        # newer, works with ghc 9.12
                        ghc-tcplugins-extra = hprev.ghc-tcplugins-extra_0_5;
                        # newer, works with ghc 9.12
                        Cabal = hprev.Cabal_3_14_2_0;
                        #  z3: createProcess: posix_spawnp: does not exist (No such file or directory)
                        rest-rewrite = hlib.dontCheck (hfinal.callHackage "rest-rewrite" "0.4.5" {});
                        # 0.9.12.2
                        liquidhaskell = hlib.addBuildDepend pkgs.z3 hprev.liquidhaskell;
                        liquid-vector = hlib.addBuildDepend pkgs.z3 hprev.liquid-vector;
                      }
                    );
                  });
                }
              )
            ];
          };
          hlib = pkgs.haskell.lib.compose;
          liquid-haskell =
            pkgs.haskellPackages.callCabal2nix "liquid-haskell" (pkgs.lib.cleanSource ./liquid-haskell)
              { };
        in
        {
          formatter = pkgs.nixfmt;
          devShells = {
            default = pkgs.haskellPackages.shellFor {
              packages = _: [
                liquid-haskell
              ];
              nativeBuildInputs = [ pkgs.haskellPackages.doctest ];
              buildInputs = [
                pkgs.cabal-install
                self'.packages.hls
                pkgs.z3
              ];
              shellHook = ''
                export PS1="\n\[\033[1;32m\][nix-shell:\W \[\033[1;31m\]FM\[\033[1;32m\]]\$\[\033[0m\] "
                echo -e "\n\033[1;31m ♣ ♠ Welcome to FM! ♥ ♦ \033[0m\n"
                echo -e "   Use the following command to open VSCode in this directory:\n"
                echo "       code ."
              '';
            };

            withVSCode = self.devShells.${system}.default.overrideAttrs (
              old:
              let
                vscode = pkgs.vscode-with-extensions.override {
                  vscodeExtensions = with pkgs.vscode-extensions; [
                    bbenoist.nix
                    haskell.haskell
                    justusadam.language-haskell
                  ];
                };
              in
              {
                buildInputs = old.buildInputs ++ [ vscode ];
                shellHook =
                  old.shellHook + ''echo -e "\n   All required extensions should be pre-installed and ready."'';
              }
            );
          };

          legacyPackages = pkgs;
          
          packages = {
            inherit liquid-haskell;
            inherit (pkgs) cabal-install;

            hls = pkgs.haskell-language-server.override {
              supportedGhcVersions = [ ghcVersion ];
            };

            # HACK: We rely on how `shellFor` constructs its `nativeBuildInputs`
            # in order to grab the `ghcWithPackages` from out of there. That way
            # we're able to globally install this GHC in the Docker image and
            # get rid of direnv as a dependency.
            ghcForFunar = builtins.head self.devShells.${system}.default.nativeBuildInputs;

            watch = pkgs.writeShellScriptBin "watch-and-commit" ''
              ${pkgs.lib.getExe pkgs.watch} -n 10 "git add . && git commit -m update && git push"
            '';
          };
        };
    };
}
