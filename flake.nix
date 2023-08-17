{
  description = "Snowfall Lib";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-22.11";
    flake-utils-plus.url = "github:gytis-ivaskevicius/flake-utils-plus";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = inputs:
    let
      core-inputs = inputs // {
        src = ./.;
      };

      # Create the library, extending the nixpkgs library and merging
      # libraries from other inputs to make them available like
      # `lib.flake-utils-plus.mkApp`.
      # Usage: mkLib { inherit inputs; src = ./.; }
      #   result: lib
      mkLib = import ./snowfall-lib core-inputs;

      # A convenience wrapper to create the library and then call `lib.mkFlake`.
      # Usage: mkFlake { inherit inputs; src = ./.; ... }
      #   result: <flake-outputs>
      mkFlake = flake-and-lib-options@{ inputs, src, snowfall ? { }, ... }:
        let
          lib = mkLib {
            inherit inputs src snowfall;
          };
          flake-options = builtins.removeAttrs flake-and-lib-options [ "inputs" "src" ];
        in
        lib.mkFlake flake-options;
    in
    {
      inherit mkLib mkFlake;

      nixosModules = {
        user = ./modules/nixos/user/default.nix;
      };

      darwinModules = {
        user = ./modules/darwin/user/default.nix;
      };

      homeModules = {
        user = ./modules/home/user/default.nix;
      };

      _snowfall = rec {
        raw-config = config;

        config = {
          root = ./.;
          src = ./.;
          namespace = "snowfall";
          lib-dir = "snowfall-lib";
        };

        internal-lib =
          let
            lib = mkLib {
              src = ./.;

              inputs = inputs // {
                self = { };
              };
            };
          in
          builtins.removeAttrs
            lib.snowfall
            [ "internal" ];
      };
    };
}
