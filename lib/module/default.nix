{ core-inputs
, user-inputs
, snowfall-lib
}:

let
  inherit (builtins) baseNameOf;
  inherit (core-inputs.nixpkgs.lib) assertMsg foldl;

  user-modules-root = snowfall-lib.fs.get-file "modules";
in
{
  module = {
    # Create flake output modules.
    # Type: Attrs -> Attrs
    # Usage: create-modules { src = ./my-modules; overrides = { inherit another-module; default = "my-module"; }; }
    #   result: { another-module = ...; my-module = ...; default = ...; }
    create-modules =
      { src ? user-modules-root
      , overrides ? { }
      }:
      let
        user-modules = snowfall-lib.fs.get-default-nix-files-recursive src;
        create-module-metadata = module: {
          name = builtins.unsafeDiscardStringContext (snowfall-lib.path.get-parent-directory module);
          path = module;
        };
        modules-metadata = builtins.map create-module-metadata user-modules;
        merge-modules = modules: metadata:
          modules // {
            ${metadata.name} = import metadata.path;
          };
        modules-without-default = foldl merge-modules { } modules-metadata;
        default-module =
          if overrides.default or null == null then
            { }
          else if builtins.isAttrs overrides.default then
            { default = overrides.default; }
          else if modules-without-default.${overrides.default} or null != null then
            { default = modules-without-default.${overrides.default}; }
          else
            { };
        overrides-without-default = builtins.removeAttrs overrides [ "default" ];
        modules = modules-without-default // default-module // overrides-without-default;
      in
      modules;
  };
}
