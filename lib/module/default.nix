{ core-inputs
, user-inputs
, snowfall-lib
}:

let
  inherit (builtins) baseNameOf;
  inherit (core-inputs.nixpkgs.lib) assertMsg foldl mapAttrs;

  user-modules-root = snowfall-lib.fs.get-snowfall-file "modules";
in
{
  module = {
    # Create flake output modules.
    # Type: Attrs -> Attrs
    # Usage: create-modules { src = ./my-modules; overrides = { inherit another-module; }; alias = { default = "another-module" }; }
    #   result: { another-module = ...; my-module = ...; default = ...; }
    create-modules =
      { src ? user-modules-root
      , overrides ? { }
      , alias ? { }
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
        modules-without-aliases = foldl merge-modules { } modules-metadata;
        aliased-modules = mapAttrs (name: value: modules-without-aliases.${value}) alias;
        modules = modules-without-aliases // aliased-modules // overrides;
      in
      modules;
  };
}
