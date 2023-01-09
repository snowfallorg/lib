{ core-inputs
, user-inputs
, snowfall-lib
}:

let
  inherit (core-inputs.flake-utils-plus.lib) filterPackages;
  inherit (core-inputs.nixpkgs.lib) assertMsg foldl mapAttrs;

  user-packages-root = snowfall-lib.fs.get-snowfall-file "packages";
in
{
  package = {
    # Create flake output packages.
    # Type: Attrs -> Attrs
    # Usage: create-packages { inherit channels; src = ./my-packages; overrides = { inherit another-package; }; alias.default = "another-package"; }
    #   result: { another-package = ...; my-package = ...; default = ...; }
    create-packages =
      { channels
      , src ? user-packages-root
      , pkgs ? channels.nixpkgs
      , overrides ? { }
      , alias ? { }
      }:
      let
        user-packages = snowfall-lib.fs.get-default-nix-files-recursive src;
        create-package-metadata = package: {
          name = builtins.unsafeDiscardStringContext (snowfall-lib.path.get-parent-directory package);
          drv = pkgs.callPackage package {
            inherit channels;
            lib = snowfall-lib.internal.system-lib;
            inputs = snowfall-lib.flake.without-src user-inputs;
          };
        };
        packages-metadata = builtins.map create-package-metadata user-packages;
        merge-packages = packages: metadata:
          packages // {
            ${metadata.name} = metadata.drv;
          };
        packages-without-aliases = foldl merge-packages { } packages-metadata;
        aliased-packages = mapAttrs (name: value: packages-without-aliases.${value}) alias;
        packages = packages-without-aliases // aliased-packages // overrides;
      in
      filterPackages pkgs.system packages;
  };
}
