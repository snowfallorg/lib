{
  core-inputs,
  user-inputs,
  snowfall-lib,
  snowfall-config,
}: let
  inherit (core-inputs.nixpkgs.lib) assertMsg foldl concatStringsSep;

  user-overlays-root = snowfall-lib.fs.get-snowfall-file "overlays";
  user-packages-root = snowfall-lib.fs.get-snowfall-file "packages";
in {
  overlay = {
    ## Create a flake-utils-plus overlays builder.
    ## Example Usage:
    ## ```nix
    ## create-overlays { src = ./my-overlays; namespace = "my-packages"; }
    ## ```
    ## Result:
    ## ```nix
    ## (channels: [ ... ])
    ## ```
    #@ Attrs -> Attrs -> [(a -> b -> c)]
    create-overlays-builder = {
      src ? user-overlays-root,
      namespace ? snowfall-config.namespace,
      extra-overlays ? [],
    }: channels: let
      user-overlays = snowfall-lib.fs.get-default-nix-files-recursive src;
      create-overlay = overlay:
        import overlay (
          # Deprecated: Use `inputs.*` instead of referencing the input name directly.
          user-inputs
          // {
            inherit channels;
            inherit (snowfall-config) namespace;
            inputs = user-inputs;
            lib = snowfall-lib.internal.system-lib;
          }
        );
      user-packages-overlay = final: prev: let
        user-packages = snowfall-lib.package.create-packages {
          pkgs = final;
          inherit channels namespace;
        };
      in {
        ${namespace} =
          (prev.${namespace} or {})
          // user-packages;
      };
      overlays =
        [user-packages-overlay] ++ extra-overlays ++ (builtins.map create-overlay user-overlays);
    in
      overlays;

    ## Create exported overlays from the user flake. Adapted [from flake-utils-plus](https://github.com/gytis-ivaskevicius/flake-utils-plus/blob/2bf0f91643c2e5ae38c1b26893ac2927ac9bd82a/lib/exportOverlays.nix).
    ##
    ## Example Usage:
    ## ```nix
    ## create-overlays { src = ./my-overlays; packages-src = ./my-packages; namespace = "my-namespace"; extra-overlays = {}; }
    ## ```
    ## Result:
    ## ```nix
    ## { default = final: prev: ...; some-overlay = final: prev: ...; }
    ## ```
    #@ Attrs -> Attrs
    create-overlays = {
      src ? user-overlays-root,
      packages-src ? user-packages-root,
      namespace ? snowfall-config.namespace,
      extra-overlays ? {},
    }: let
      fake-pkgs = {
        callPackage = x: x;
        isFakePkgs = true;
        lib = {};
        system = "fake-system";
      };

      user-overlays = snowfall-lib.fs.get-default-nix-files-recursive src;

      channel-systems = user-inputs.self.pkgs;

      user-packages-overlay = final: prev: let
        user-packages = snowfall-lib.package.create-packages {
          pkgs = final;
          channels = channel-systems.${prev.system};
          inherit namespace;
        };
      in
        if namespace == null
        then user-packages
        else {
          ${namespace} =
            (prev.${namespace} or {})
            // user-packages;
        };

      create-overlay = (
        overlays: file: let
          name = builtins.unsafeDiscardStringContext (snowfall-lib.path.get-parent-directory file);
          overlay = final: prev: let
            channels = channel-systems.${prev.system};
            user-overlay = import file (
              # Deprecated: Use `inputs.*` instead of referencing the input name directly.
              user-inputs
              // {
                inherit channels namespace;
                inputs = user-inputs;
                lib = snowfall-lib.internal.system-lib;
              }
            );
            packages = user-packages-overlay final prev;
            prev-with-packages =
              if namespace == null
              then prev // packages
              else
                prev
                // {
                  ${namespace} =
                    (prev.${namespace} or {})
                    // packages.${namespace};
                };
            user-overlay-packages =
              user-overlay
              final
              prev-with-packages;
            outputs =
              user-overlay-packages;
          in
            if user-overlay-packages.__dontExport or false == true
            then outputs // {__dontExport = true;}
            else outputs;
          fake-overlay-result = overlay fake-pkgs fake-pkgs;
        in
          if fake-overlay-result.__dontExport or false == true
          then overlays
          else
            overlays
            // {
              ${name} = overlay;
            }
      );

      overlays =
        foldl
        create-overlay
        {}
        user-overlays;

      user-packages = snowfall-lib.fs.get-default-nix-files-recursive packages-src;

      create-package-overlay = package-overlays: file: let
        name = builtins.unsafeDiscardStringContext (snowfall-lib.path.get-parent-directory file);
        overlay = final: prev: let
          channels = channel-systems.${prev.system};
          packages = snowfall-lib.package.create-packages {
            inherit namespace;
            channels = channel-systems.${prev.system};
          };
        in
          if namespace == null
          then {${name} = packages.${name};}
          else {
            ${namespace} =
              (prev.${namespace} or {})
              // {${name} = packages.${name};};
          };
      in
        package-overlays
        // {
          "package/${name}" = overlay;
        };

      package-overlays =
        foldl
        create-package-overlay
        {}
        user-packages;

      default-overlay = final: prev: let
        overlays-list = builtins.attrValues overlays;
        package-overlays-list = builtins.attrValues package-overlays;

        overlays-results = builtins.map (overlay: overlay final prev) overlays-list;
        package-overlays-results = builtins.map (overlay: overlay final prev) package-overlays-list;

        merged-results =
          snowfall-lib.attrs.merge-shallow-packages
          (package-overlays-results ++ overlays-results);
      in
        merged-results;
    in
      package-overlays
      // overlays
      // {default = default-overlay;}
      // extra-overlays;
  };
}
