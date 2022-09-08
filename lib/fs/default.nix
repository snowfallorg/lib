{ core-inputs
, user-inputs
, snowfall-lib
}:

let
  inherit (builtins) readDir pathExists;
  inherit (core-inputs) flake-utils-plus;
  inherit (core-inputs.nixpkgs.lib) assertMsg filterAttrs mapAttrsToList flatten;

  file-name-regex = "(.*)\\.(.*)$";
in
{
  fs = rec {
    # Matchers for file kinds. These are often used with `readDir`.
    # Type: String -> Bool
    # Usage: is-file-kind "directory"
    #   result: false
    is-file-kind = kind: kind == "regular";
    is-symlink-kind = kind: kind == "symlink";
    is-directory-kind = kind: kind == "directory";
    is-unknown-kind = kind: kind == "unknown";

    # Get a file path relative to the user's flake.
    # Type: Path -> Path
    # Usage: get-file "systems"
    #   result: "/user-source/systems"
    get-file = path: "${user-inputs.src}/${path}";

    # Get a file path relative to the this flake.
    # Type: Path -> Path
    # Usage: get-file "systems"
    #   result: "/user-source/systems"
    internal-get-file = path: "${core-inputs.src}/${path}";

    # Safely read from a directory if it exists.
    # Type: Path -> Attrs
    # Usage: safe-read-directory ./some/path
    #   result: { "my-file.txt" = "regular"; }
    safe-read-directory = path:
      if pathExists path then
        readDir path
      else
        {};

    # Get directories at a given path.
    # Type: Path -> [Path]
    # Usage: get-directories ./something
    #   result: [ "./something/a-directory" ]
    get-directories = path:
      let
        entries = safe-read-directory path;
        filtered-entries = filterAttrs (name: kind: is-directory-kind kind) entries;
      in
        mapAttrsToList (name: kind: "${path}/${name}") filtered-entries;

    # Get files at a given path.
    # Type: Path -> [Path]
    # Usage: get-files ./something
    #   result: [ "./something/a-file" ]
    get-files = path:
      let
        entries = safe-read-directory path;
        filtered-entries = filterAttrs (name: kind: is-file-kind kind) entries;
      in
        mapAttrsToList (name: kind: "${path}/${name}") filtered-entries;

    # Get files at a given path, traversing any directories within.
    # Type: Path -> [Path]
    # Usage: get-files-recursive ./something
    #   result: [ "./something/some-directory/a-file" ]
    get-files-recursive = path:
      let
        entries = safe-read-directory path;
        filtered-entries =
          filterAttrs
            (name: kind: (is-file-kind kind) || (is-directory-kind kind))
            entries;
        map-file = name: kind:
          let
            path' = "${path}/${name}";
          in if is-directory-kind kind then
            get-files-recursive path'
          else
            path';
        files = snowfall-lib.attrs.map-concat-attrs-to-list
          map-file
          filtered-entries;
      in
      files;

    # Get nix files at a given path.
    # Type: Path -> [Path]
    # Usage: get-nix-files "./something"
    #   result: [ "./something/a.nix" ]
    get-nix-files = path:
      builtins.filter
        (snowfall-lib.path.has-file-extension "nix")
        (get-files path);

    # Get nix files at a given path, traversing any directories within.
    # Type: Path -> [Path]
    # Usage: get-nix-files "./something"
    #   result: [ "./something/a.nix" ]
    get-nix-files-recursive = path:
      builtins.filter
        (snowfall-lib.path.has-file-extension "nix")
        (get-files-recursive path);

    # Get nix files at a given path named "default.nix".
    # Type: Path -> [Path]
    # Usage: get-default-nix-files "./something"
    #   result: [ "./something/default.nix" ]
    get-default-nix-files = path:
      builtins.filter
        (name: builtins.baseNameOf name == "default.nix")
        (get-files path);

    # Get nix files at a given path named "default.nix", traversing any directories within.
    # Type: Path -> [Path]
    # Usage: get-default-nix-files-recursive "./something"
    #   result: [ "./something/some-directory/default.nix" ]
    get-default-nix-files-recursive = path:
      builtins.filter
      (name: builtins.baseNameOf name == "default.nix")
      (get-files-recursive path);

    # Get nix files at a given path not named "default.nix".
    # Type: Path -> [Path]
    # Usage: get-non-default-nix-files "./something"
    #   result: [ "./something/a.nix" ]
    get-non-default-nix-files = path:
      builtins.filter
        (name:
          (snowfall-lib.path.has-file-extension "nix" name)
          && (builtins.baseNameOf name != "default.nix")
        )
        (get-files path);

    # Get nix files at a given path not named "default.nix",
    # traversing any directories within.
    # Type: Path -> [Path]
    # Usage: get-non-default-nix-files-recursive "./something"
    #   result: [ "./something/some-directory/a.nix" ]
    get-non-default-nix-files-recursive = path:
      builtins.filter
      (name:
        (snowfall-lib.path.has-file-extension "nix" name)
        && (builtins.baseNameOf name != "default.nix")
      )
      (get-files-recursive path);
  };
}
