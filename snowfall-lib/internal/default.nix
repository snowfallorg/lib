{
  core-inputs,
  user-inputs,
  snowfall-lib,
  snowfall-config,
}: let
  inherit (core-inputs.nixpkgs.lib) assertMsg fix fold filterAttrs callPackageWith;

  core-inputs-libs = snowfall-lib.flake.get-libs (snowfall-lib.flake.without-self core-inputs);
  user-inputs-libs = snowfall-lib.flake.get-libs (snowfall-lib.flake.without-self user-inputs);

  snowfall-top-level-lib = filterAttrs (name: value: !builtins.isAttrs value) snowfall-lib;

  base-lib = snowfall-lib.attrs.merge-shallow [
    core-inputs.nixpkgs.lib
    core-inputs-libs
    user-inputs-libs
    snowfall-top-level-lib
    {snowfall = snowfall-lib;}
  ];

  user-lib-root = snowfall-lib.fs.get-file "lib";
  user-lib-modules = snowfall-lib.fs.get-default-nix-files-recursive user-lib-root;

  user-lib = fix (
    user-lib: let
      attrs = {
        inputs = snowfall-lib.flake.without-snowfall-inputs user-inputs;
        snowfall-inputs = core-inputs;
        lib = snowfall-lib.attrs.merge-shallow [
          base-lib
          {internal = user-lib;}
        ];
      };
      libs =
        builtins.map
        (path: callPackageWith attrs path {})
        user-lib-modules;
    in
      snowfall-lib.attrs.merge-deep libs
  );

  system-lib = snowfall-lib.attrs.merge-shallow [
    base-lib
    {"${snowfall-config.namespace}" = user-lib;}
  ];
in {
  internal = {
    inherit system-lib user-lib;
  };
}
