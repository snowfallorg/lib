{ core-inputs
, user-inputs
, snowfall-lib
, snowfall-config
}:

let
  inherit (builtins) toString baseNameOf dirOf concatStringsSep;
  inherit (core-inputs.nixpkgs.lib) assertMsg last init;

  file-name-regex = "(.*)\\.(.*)$";
in
{
  path = rec {
    # Split a file name and its extension.
    # Type: String -> [String]
    # Usage: split-file-extension "my-file.md"
    #   result: [ "my-file" "md" ]
    split-file-extension = file:
      let
        match = builtins.match file-name-regex file;
      in
      assert assertMsg (match != null) "lib.snowfall.split-file-extension: File must have an extension to split.";
      match;

    # Check if a file name has a file extension.
    # Type: String -> Bool
    # Usage: has-any-file-extension "my-file.txt"
    #   result: true
    has-any-file-extension = file:
      let
        match = builtins.match file-name-regex (toString file);
      in
      match != null;

    # Get the file extension of a file name.
    # Type: String -> String
    # Usage: get-file-extension "my-file.final.txt"
    #   result: "txt"
    get-file-extension = file:
      if has-any-file-extension file then
        let
          match = builtins.match file-name-regex (toString file);
        in
        last match
      else
        "";

    # Check if a file name has a specific file extension.
    # Type: String -> String -> Bool
    # Usage: has-file-extension "txt" "my-file.txt"
    #   result: true
    has-file-extension = extension: file:
      if has-any-file-extension file then
        extension == get-file-extension file
      else
        false;

    # Get the parent directory for a given path.
    # Type: Path -> Path
    # Usage: get-parent-directory "/a/b/c"
    #   result: "/a/b"
    get-parent-directory = snowfall-lib.fp.compose baseNameOf dirOf;

    # Get the file name of a path without its extension.
    # Type: Path -> String
    # Usage: get-file-name-without-extension ./some-directory/my-file.pdf
    #   result: "my-file"
    get-file-name-without-extension = path:
      let
        file-name = baseNameOf path;
      in
      if has-any-file-extension file-name then
        concatStringsSep "" (init (split-file-extension file-name))
      else
        file-name;
  };
}
