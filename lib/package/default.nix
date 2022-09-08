{ core-inputs
, user-inputs
, snowfall-lib
}:

let
  inherit (core-inputs.nixpkgs.lib) assertMsg foldl;

  user-packages-root = snowfall-lib.fs.get-file "packages";
in
{
  package = {
    # Create flake output packages.
    # Type: Attrs -> Attrs
    # Usage: create-packages { inherit channels; src = ./my-packages; overrides = { inherit another-package; default = "my-package"; }; }
    #   result: { another-package = ...; my-package = ...; default = ...; }
    create-packages =
      { channels
      , src ? user-packages-root
      , overrides ? { }
      }:
      let
        user-packages = snowfall-lib.fs.get-default-nix-files-recursive src;
        create-package-metadata = package: {
          name = builtins.unsafeDiscardStringContext (snowfall-lib.path.get-parent-directory package);
          drv = channels.nixpkgs.callPackage package {
            inherit channels;
            lib = snowfall-lib.internal.system-lib;
          };
        };
        packages-metadata = builtins.map create-package-metadata user-packages;
        merge-packages = packages: metadata:
          packages // {
            ${metadata.name} = metadata.drv;
          };
        packages-without-default = foldl merge-packages { } packages-metadata;
        default-package =
          if overrides.default or null == null then
            { }
          else if builtins.isAttrs overrides.default then
            { default = overrides.default; }
          else if packages-without-default.${overrides.default} or null != null then
            { default = packages-without-default.${overrides.default}; }
          else
            { };
        overrides-without-default = builtins.removeAttrs overrides [ "default" ];
        packages = packages-without-default // default-package // overrides-without-default;
      in
      packages;
  };
}
