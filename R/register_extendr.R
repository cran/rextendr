#' Register the extendr module of a package with R
#'
#' This function generates wrapper code corresponding to the extendr module
#' for an R package. This is useful in package development, where we generally
#' want appropriate R code wrapping the Rust functions implemented via extendr.
#' In most development settings, you will not want to call this function directly,
#' but instead call `rextendr::document()`.
#'
#' The function `register_extendr()` compiles the package Rust code if
#' required, and then the wrapper code is retrieved from the compiled
#' Rust code and saved into `R/extendr-wrappers.R`. Afterwards, you will have
#' to re-document and then re-install the package for the wrapper functions to
#' take effect.
#'
#' @param path Path from which package root is looked up.
#' @param quiet Logical indicating whether any progress messages should be
#'   generated or not.
#' @param force Logical indicating whether to force regenerating
#'   `R/extendr-wrappers.R` even when it doesn't seem to need updated. (By
#'   default, generation is skipped when it's newer than the DLL).
#' @param compile Logical indicating whether to recompile DLLs:
#'   \describe{
#'     \item{`TRUE`}{always recompiles}
#'     \item{`NA`}{recompiles if needed (i.e., any source files or manifest file are newer than the DLL)}
#'     \item{`FALSE`}{never recompiles}
#'   }
#' @return (Invisibly) Path to the file containing generated wrappers.
#' @seealso [rextendr::document()]
#' @export
register_extendr <- function(path = ".", quiet = FALSE, force = FALSE, compile = NA) {
  local_quiet_cli(quiet)

  rextendr_setup(path = path)

  pkg_name <- pkg_name(path)

  cli::cli_alert_info("Generating extendr wrapper functions for package: {.pkg {pkg_name}}.")

  entrypoint_c_file <- rprojroot::find_package_root_file("src", "entrypoint.c", path = path)
  if (!file.exists(entrypoint_c_file)) {
    cli::cli_abort(
      c(
        "Unable to register the extendr module.",
        "x" = "Could not find file {.file src/entrypoint.c}.",
        "*" = "Are you sure this package is using extendr Rust code?"
      ),
      class = "rextendr_error"
    )
  }

  outfile <- rprojroot::find_package_root_file("R", "extendr-wrappers.R", path = path)

  path <- rprojroot::find_package_root_file(path = path)

  if (!isFALSE(compile)) {
    # As of version 1.4.0, pkgbuild can detect the changes in Rust code.
    pkgbuild::compile_dll(path = path, quiet = quiet, force = compile)
  }

  library_path <- get_library_path(path)

  if (!file.exists(library_path)) {
    msg <- "{library_path} doesn't exist"
    if (isTRUE(compile)) {
      # If it doesn't exist even after compile, we have no idea what happened
      cli::cli_abort(msg, class = "rextendr_error")
    } else {
      # If compile wasn't invoked, it might succeed with explicit "compile = TRUE"
      cli::cli_abort(
        c(
          msg,
          "i" = "You need to compile first, try {.code register_rextendr(compile = TRUE)}."
        ),
        class = "rextendr_error"
      )
    }
  }

  # If the wrapper file is newer than the DLL file, assume it's been generated
  # by the latest DLL, which should mean it doesn't need to be regenerated.
  # This isn't always the case (e.g. when the user accidentally edited the
  # wrapper file by hand) so the user might need to run with `force = TRUE`.
  if (!isTRUE(force) && isTRUE(file.info(outfile)[["mtime"]] > file.info(library_path)[["mtime"]])) {
    rel_path <- pretty_rel_path(outfile, path) # nolint: object_usage_linter
    cli::cli_alert_info("{.file {rel_path}} is up-to-date. Skip generating wrapper functions.")

    return(invisible(character(0L)))
  }

  tryCatch(
    # Call the wrapper generation in a separate R process to avoid the problem
    # of loading and unloading the same name of a DLL (c.f. #64).
    make_wrappers_externally(
      module_name = as_valid_rust_name(pkg_name),
      package_name = pkg_name,
      outfile = outfile,
      path = path,
      use_symbols = TRUE,
      quiet = quiet
    ),
    error = function(e) {
      cli::cli_abort(
        c("Failed to generate wrapper functions.",
          x = e[["message"]],
          y = e[["parent"]][["message"]]
        ),
        class = "rextendr_error"
      )
    }
  )

  # Ensures path is absolute
  invisible(normalizePath(outfile))
}

#' Creates R wrappers for Rust functions.
#'
#' Invokes `wrap__make_{module_name}_wrappers` exported from
#' the Rust library and writes obtained R wrappers to the `outfile`.
#' @param module_name The name of the Rust module. Can be the same as `package_name`
#' @param package_name The name of the package.
#' @param outfile Determines where to write wrapper code.
#' @param path Path from which package root is looked up. Used for message formatting.
#' @param use_symbols Logical, indicating wether to add additional symbol information to
#' the generated wrappers. Default (`FALSE`) is used when making wrappers for the package,
#' while `TRUE` is used to make wrappers for dynamically generated libraries using
#' [`rust_source`], [`rust_function`], etc.
#' @param quiet Logical scalar indicating whether the output should be quiet (`TRUE`)
#'   or verbose (`FALSE`).
#' @noRd
make_wrappers <- function(module_name, package_name, outfile,
                          path = ".", use_symbols = FALSE, quiet = FALSE) {
  wrapper_function <- glue("wrap__make_{module_name}_wrappers")
  x <- .Call(
    wrapper_function,
    use_symbols = use_symbols,
    package_name = package_name,
    PACKAGE = package_name
  )
  generated_wrappers <- stringi::stri_split_lines1(x)

  generated_wrappers <- c(
    generated_wrappers[1],
    "",
    "# nolint start",
    "",
    generated_wrappers[-1],
    "",
    "# nolint end"
  )

  write_file(
    text = generated_wrappers,
    path = outfile,
    search_root_from = path,
    quiet = quiet
  )
}

#' Creates R wrappers for Rust functions.
#'
#' Does the same as [`make_wrappers`], but out of process.
#' @inheritParams make_wrappers
#' @noRd
make_wrappers_externally <- function(module_name, package_name, outfile,
                                     path, use_symbols = FALSE, quiet = FALSE) {
  func <- function(path, make_wrappers, quiet,
                   module_name, package_name, outfile,
                   use_symbols, ...) {
    library_path <- file.path(path, "src", paste0(package_name, .Platform$dynlib.ext))
    # Loads native library
    lib <- dyn.load(library_path)
    # Registers library unloading to be invoked at the end of this function
    withr::defer(dyn.unload(lib[["path"]]))

    make_wrappers(
      module_name = module_name,
      package_name = package_name,
      outfile = outfile,
      path = path,
      use_symbols = use_symbols,
      quiet = quiet
    )
  }

  args <- list(
    path = rprojroot::find_package_root_file(path = path),
    make_wrappers = make_wrappers,
    # arguments passed to make_wrappers()
    module_name = module_name,
    package_name = package_name,
    outfile = outfile,
    use_symbols = use_symbols,
    quiet = quiet
  )

  invisible(callr::r(func, args = args, show = !isTRUE(quiet)))
}
