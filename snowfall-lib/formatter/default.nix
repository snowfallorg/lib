{
  core-inputs,
  user-inputs,
  snowfall-lib,
  snowfall-config,
}: let
  inherit (core-inputs.flake-utils-plus.lib) filterPackages;
  inherit (core-inputs.nixpkgs.lib) assertMsg foldl mapAttrs callPackageWith;

  user-formatters-root = snowfall-lib.fs.get-snowfall-file "formatter";
in {
  formatter = {
    ## Create flake output packages.
    ## Example Usage:
    ## ```nix
    ## create-formatter { inherit channels; src = ./my-formatters; }
    ## ```
    ## Result:
    ## ```nix
    ## <<derivation ...>>
    ## ```
    #@ Attrs -> Drv
    create-formatter = {
      channels,
      src ? user-formatters-root,
      pkgs ? channels.nixpkgs,
    }: let
      user-formatters = snowfall-lib.fs.get-default-nix-files src;
      create-formatter-metadata = formatter: let
        extra-inputs =
          pkgs
          // {
            inherit channels;
            lib = snowfall-lib.internal.system-lib;
            inputs = snowfall-lib.flake.without-src user-inputs;
            namespace = snowfall-config.namespace;
          };
      in {
        name = "formatter";
        drv = callPackageWith extra-inputs formatter {};
      };
      formatters-metadata = builtins.map create-formatter-metadata user-formatters;
      merge-formatters = formatters: metadata:
        formatters
        // {
          ${metadata.name} = metadata.drv;
        };
      formatters-without-aliases = foldl merge-formatters {} formatters-metadata;
      formatters = formatters-without-aliases;
    in
      (filterPackages pkgs.system formatters).formatter;
  };
}
