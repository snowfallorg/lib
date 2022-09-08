{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-22.05";
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
      mkLib = import ./lib core-inputs;

      # A convenience wrapper to create the library and then call `lib.mkFlake`.
      # Usage: mkFlake { inherit inputs; src = ./.; ... }
      #   result: <flake-outputs>
      mkFlake = flake-and-lib-options@{ inputs, src, ... }:
        let
          lib = mkLib {
            inherit inputs src;
          };
          flake-options = builtins.removeAttrs flake-and-lib-options [ "inputs" "src" ];
        in
          lib.mkFlake flake-options;
    in
    {
      inherit mkLib mkFlake;
    };
}
