{ core-inputs
, user-inputs
, snowfall-lib
}:

let
  inherit (core-inputs.nixpkgs.lib) assertMsg fold filterAttrs const;
in
rec {
  flake = rec {
    # Remove the `self` attribute from an attribute set.
    # Type: Attrs -> Attrs
    # Usage: without-self { self = {}; x = true; }
    #   result: { x = true; }
    without-self = flake-inputs: builtins.removeAttrs flake-inputs [ "self" ];

    # Remove the `src` attribute from an attribute set.
    # Type: Attrs -> Attrs
    # Usage: without-src { src = ./.; x = true; }
    #   result: { x = true; }
    without-src = flake-inputs: builtins.removeAttrs flake-inputs [ "src" ];

    # Remove the `src` and `self` attributes from an attribute set.
    # Type: Attrs -> Attrs
    # Usage: without-snowfall-inputs { self = {}; src = ./.; x = true; }
    #   result: { x = true; }
    without-snowfall-inputs = snowfall-lib.fp.compose without-self without-src;

    # Remove Snowfall-specific attributes so the rest can be safely
    # passed to flake-utils-plus.
    # Type: Attrs -> Attrs
    # Usage: without-snowfall-options { src = ./.; x = true; }
    #   result: { x = true; }
    without-snowfall-options = flake-options:
      builtins.removeAttrs
        flake-options
        [
          "systems"
          "modules"
          "overlays"
          "packages"
          "outputs-builder"
          "outputsBuilder"
          "packagesPrefix"
          "hosts"
          "channels-config"
          "templates"
        ];

    # Transform an attribute set of inputs into an attribute set where
    # the values are the inputs' `lib` attribute. Entries without a `lib`
    # attribute are removed.
    # Type: Attrs -> Attrs
    # Usage: get-lib { x = nixpkgs; y = {}; }
    #   result: { x = nixpkgs.lib; }
    get-libs = attrs:
      let
        # @PERF(jakehamilton): Replace filter+map with a fold.
        attrs-with-libs = filterAttrs
          (name: value: builtins.isAttrs (value.lib or null))
          attrs;
        libs =
          builtins.mapAttrs (name: input: input.lib) attrs-with-libs;
      in
      libs;

  };

  mkFlake = full-flake-options:
    let
      custom-flake-options = flake.without-snowfall-options full-flake-options;
      systems = snowfall-lib.system.create-systems (full-flake-options.systems or {});
      hosts = snowfall-lib.attrs.merge-shallow [ (full-flake-options.systems.hosts or {}) systems ];
      templates = snowfall-lib.template.create-templates {
        overrides = (full-flake-options.templates or {});
      };
      modules = snowfall-lib.module.create-modules {
        overrides = (full-flake-options.modules or {});
      };

      outputs-builder = channels:
        let
          user-outputs-builder =
            full-flake-options.outputs-builder
            or full-flake-options.outputsBuilder
            or (const {});
          user-outputs = user-outputs-builder channels;
          packages = snowfall-lib.package.create-packages {
            inherit channels;
            overrides = (full-flake-options.packages or {}) // (user-outputs.packages or {});
          };
          shells = snowfall-lib.shell.create-shells {
            inherit channels;
            overrides = (full-flake-options.shells or {}) // (user-outputs.devShells or {});
          };

          outputs = {
            inherit packages;

            devShells = shells;
          };
        in
        snowfall-lib.attrs.merge-deep [ user-outputs outputs ];

      flake-options = custom-flake-options // {
        inherit hosts templates;
        inherit (user-inputs) self;

        lib = snowfall-lib.internal.system-lib;
        inputs = snowfall-lib.flake.without-src user-inputs;

        nixosModules = modules;

        channelsConfig = full-flake-options.channels-config or {};

        overlays = core-inputs.flake-utils-plus.lib.exportOverlays ({
          inherit (user-inputs.self) pkgs;
          inputs = user-inputs;
        });

        channels.nixpkgs.overlaysBuilder = snowfall-lib.overlay.create-overlays {
          overlay-package-namespace = full-flake-options.overlay-package-namespace or null;
          extra-overlays = full-flake-options.overlays or [];
        };

        outputsBuilder = outputs-builder;
      };
    in
    core-inputs.flake-utils-plus.lib.mkFlake flake-options;
}
