{ core-inputs
, user-inputs
, snowfall-lib
}:

let
  inherit (core-inputs.nixpkgs.lib) assertMsg foldl concatStringsSep;

  user-overlays-root = snowfall-lib.fs.get-file "overlays";
  user-packages-root = snowfall-lib.fs.get-file "packages";
in
{
  overlay = {
    # Create a flake-utils-plus overlays builder.
    # Type: Attrs -> Attrs -> [(a -> b -> c)]
    # Usage: create-overlays { src = ./my-overlays; overlay-package-namespace = "my-packages"; }
    #   result: (channels: [ ... ])
    create-overlays-builder =
      { src ? user-overlays-root
      , overlay-package-namespace ? null
      , extra-overlays ? [ ]
      }: channels:
      let
        user-overlays = snowfall-lib.fs.get-default-nix-files-recursive src;
        create-overlay = overlay: import overlay (user-inputs // { inherit channels; });
        user-packages-overlay = final: prev:
          let
            user-packages = snowfall-lib.package.create-packages {
              pkgs = final;
              channels = channels;
            };
            user-packages-without-default = builtins.removeAttrs
              (user-packages) [ "default" ];
          in
          if overlay-package-namespace == null then
            user-packages-without-default
          else
            {
              ${overlay-package-namespace} =
                (prev.${overlay-package-namespace} or { })
                // user-packages-without-default;
            };
        overlays = [ user-packages-overlay ] ++ extra-overlays ++ (builtins.map create-overlay user-overlays);
      in
      overlays;

    # Create exported overlays from the user flake.
    # Adapted from flake-utils-plus:
    # https://github.com/gytis-ivaskevicius/flake-utils-plus/blob/2bf0f91643c2e5ae38c1b26893ac2927ac9bd82a/lib/exportOverlays.nix
    # Type: Attrs -> Attrs
    # Usage: create-overlays { src = ./my-overlays; packages-src = ./my-packages; overlay-package-namespace = "my-namespace"; extra-overlays = {}; }
    #   result: { default = final: prev: ...; some-overlay = final: prev: ...; }
    create-overlays =
      { src ? user-overlays-root
      , packages-src ? user-packages-root
      , overlay-package-namespace ? null
      , extra-overlays ? { }
      }:
      let
        fake-pkgs = {
          callPackage = x: x;
          isFakePkgs = true;
          lib = { };
          system = "fake-system";
        };

        user-overlays = snowfall-lib.fs.get-default-nix-files-recursive src;

        channel-systems = user-inputs.self.pkgs;

        user-packages-overlay = final: prev:
          let
            user-packages = snowfall-lib.package.create-packages {
              pkgs = final;
              channels = channel-systems.${prev.system};
            };
          in
          if overlay-package-namespace == null then
            user-packages
          else
            {
              ${overlay-package-namespace} =
                (prev.${overlay-package-namespace} or { })
                // user-packages;
            };

        create-overlay = (overlays: file:
          let
            name = builtins.unsafeDiscardStringContext (snowfall-lib.path.get-parent-directory file);
            overlay = final: prev:
              let
                channels = channel-systems.${prev.system};
                user-overlay = import file (user-inputs // { inherit channels; });
                packages = user-packages-overlay final prev;
                prev-with-packages =
                  if overlay-package-namespace == null then
                    prev // packages
                  else
                    prev // {
                      ${overlay-package-namespace} =
                        (prev.${overlay-package-namespace} or { })
                        // packages.${overlay-package-namespace};
                    };
                user-overlay-packages =
                  user-overlay
                    final
                    prev-with-packages;
                outputs =
                  user-overlay-packages;
              in
              if user-overlay-packages.__dontExport or false == true then
                outputs // { __dontExport = true; }
              else
                outputs;
            fake-overlay-result = overlay fake-pkgs fake-pkgs;
          in
          if fake-overlay-result.__dontExport or false == true then
            overlays
          else
            overlays // {
              "nixpkgs/${name}" = overlay;
            }
        );

        overlays =
          foldl
            create-overlay
            { }
            user-overlays;

        user-packages = snowfall-lib.fs.get-default-nix-files-recursive packages-src;

        create-package-overlay = package-overlays: file:
          let
            name = builtins.unsafeDiscardStringContext (snowfall-lib.path.get-parent-directory file);
            overlay = final: prev:
              let
                channels = channel-systems.${prev.system};
                packages = snowfall-lib.package.create-packages {
                  channels = channel-systems.${prev.system};
                };
              in
              if overlay-package-namespace == null then
                { ${name} = packages.${name}; }
              else
                {
                  ${overlay-package-namespace} =
                    (prev.${overlay-package-namespace} or { })
                    // { ${name} = packages.${name}; };
                };
          in
          package-overlays //
          {
            "nixpkgs/${name}" = overlay;
          };

        package-overlays =
          foldl
            create-package-overlay
            { }
            user-packages;

        default-overlay = final: prev:
          let
            overlays-list = builtins.attrValues overlays;
            package-overlays-list = builtins.attrValues package-overlays;

            overlays-results = builtins.map (overlay: overlay final prev) overlays-list;
            package-overlays-results = builtins.map (overlay: overlay final prev) package-overlays-list;

            merged-results = snowfall-lib.attrs.merge-shallow-packages
              (package-overlays-results ++ overlays-results);
          in
          merged-results;
      in
      package-overlays
      // overlays
      // { default = default-overlay; }
      // extra-overlays;
  };
}

