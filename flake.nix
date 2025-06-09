{
  description = "Concatted Vim/NVim help";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    nur = {
      url = "github:Omochice/nur-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
      flake-utils,
      nur,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ nur.overlays.default ];
        };
        treefmt = treefmt-nix.lib.evalModule pkgs (
          { ... }:
          {
            settings.global.excludes = [
              "CHANGELOG.md"
              "vim"
              "neovim"
            ];
            programs = {
              # keep-sorted start block=yes
              formatjson5 = {
                enable = true;
                indent = 2;
              };
              keep-sorted.enable = true;
              mdformat.enable = true;
              nixfmt.enable = true;
              yamlfmt = {
                enable = true;
                settings = {
                  formatter = {
                    type = "basic";
                    retain_line_breaks_single = true;
                  };
                };
              };
            };
            # keep-sorted end
          }
        );
        runAs =
          name: runtimeInputs: text:
          let
            program = pkgs.writeShellApplication {
              inherit name text runtimeInputs;
            };
          in
          {
            type = "app";
            program = "${program}/bin/${name}";
          };
        concat =
          target:
          pkgs.stdenvNoCC.mkDerivation {
            pname = "concat-${target}-help";
            version = "0.1.0";
            src = ./.;
            nativeBuildInputs = [
              pkgs.uutils-coreutils
            ];
            installPhase = ''
              mkdir -p $out
              cat ${target}/runtime/doc/help.txt > $out/${target}.txt
              ls ${target}/runtime/doc/*.txt | grep -v help.txt | sort | while read file; do
                cat $file >> $out/${target}.txt
              done
            '';
          };
        vim = concat "vim";
        neovim = concat "neovim";
      in
      {
        formatter = treefmt.config.build.wrapper;
        checks = {
          formatting = treefmt.config.build.check self;
        };
        apps = {
          check-actions =
            ''
              actionlint
              ghalint run
              zizmor .github/workflows
            ''
            |> runAs "check-actions" [
              pkgs.actionlint
              pkgs.ghalint
              pkgs.zizmor
            ];
          check-renovate-config =
            "renovate-config-validator renovate.json5" |> runAs "check-renovate-config" [ pkgs.renovate ];
        };
        packages = {
          inherit vim neovim;
          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "concat-help";
            version = "0.1.0";
            src = ./.;
            installPhase = ''
              mkdir -p $out
              cp ${vim}/vim.txt $out/vim.txt
              cp ${neovim}/neovim.txt $out/neovim.txt
            '';
          };
        };
      }
    );
}
