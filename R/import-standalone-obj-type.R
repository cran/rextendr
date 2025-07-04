# Standalone file: do not edit by hand
# Source: <https://github.com/r-lib/rlang/blob/main/R/standalone-obj-type.R>
# ----------------------------------------------------------------------
#
# ---
# repo: r-lib/rlang
# file: standalone-obj-type.R
# last-updated: 2023-05-01
# license: https://unlicense.org
# imports: rlang (>= 1.1.0)
# ---
#
# ## Changelog
#
# 2023-05-01:
# - `obj_type_friendly()` now only displays the first class of S3 objects.
#
# 2023-03-30:
# - `stop_input_type()` now handles `I()` input literally in `arg`.
#
# 2022-10-04:
# - `obj_type_friendly(value = TRUE)` now shows numeric scalars
#   literally.
# - `stop_friendly_type()` now takes `show_value`, passed to
#   `obj_type_friendly()` as the `value` argument.
#
# 2022-10-03:
# - Added `allow_na` and `allow_null` arguments.
# - `NULL` is now backticked.
# - Better friendly type for infinities and `NaN`.
#
# 2022-09-16:
# - Unprefixed usage of rlang functions with `rlang::` to
#   avoid onLoad issues when called from rlang (#1482).
#
# 2022-08-11:
# - Prefixed usage of rlang functions with `rlang::`.
#
# 2022-06-22:
# - `friendly_type_of()` is now `obj_type_friendly()`.
# - Added `obj_type_oo()`.
#
# 2021-12-20:
# - Added support for scalar values and empty vectors.
# - Added `stop_input_type()`
#
# 2021-06-30:
# - Added support for missing arguments.
#
# 2021-04-19:
# - Added support for matrices and arrays (#141).
# - Added documentation.
# - Added changelog.
#
# nocov start

#' Return English-friendly type
#' @param x Any R object.
#' @param value Whether to describe the value of `x`. Special values
#'   like `NA` or `""` are always described.
#' @return A string describing the type. Starts with an indefinite
#'   article, e.g. "an integer vector".
#' @noRd
obj_type_friendly <- function(x, value = TRUE) {
  if (rlang::is_missing(x)) {
    return("absent")
  }

  if (is.object(x)) {
    if (inherits(x, "quosure")) {
      type <- "quosure"
    } else {
      type <- class(x)[[1L]]
    }
    return(sprintf("a <%s> object", type))
  }

  if (!rlang::is_vector(x)) {
    return(.rlang_as_friendly_type(typeof(x)))
  }

  n_dim <- length(dim(x))

  if (!n_dim) {
    return(vec_or_scalar_type_friendly(x, value))
  }
  vec_type_friendly(x)
}

vec_or_scalar_type_friendly <- function(x, value) {
  if (!rlang::is_list(x) && length(x) == 1) {
    if (rlang::is_na(x)) {
      return(.match_na_scalar(x))
    }

    if (value) {
      return(.make_description(x))
    }

    return(.match_default_scalar(x))
  }

  if (length(x) == 0) {
    return(.match_empty_object(x))
  }
  vec_type_friendly(x)
}

.show_infinities <- function(x) {
  if (x > 0) {
    "`Inf`"
  } else {
    "`-Inf`"
  }
}

.str_encode <- function(x, width = 30, ...) {
  if (nchar(x) > width) {
    x <- substr(x, 1, width - 3)
    x <- paste0(x, "...")
  }
  encodeString(x, ...)
}

.make_description <- function(x) {
  if (is.numeric(x) && is.infinite(x)) {
    return(.show_infinities(x))
  }

  if (is.numeric(x) || is.complex(x)) {
    number <- as.character(round(x, 2))
    what <- if (is.complex(x)) "the complex number" else "the number"
    return(paste(what, number))
  }

  switch(typeof(x),
    logical = if (x) "`TRUE`" else "`FALSE`",
    character = {
      what <- if (nzchar(x)) "the string" else "the empty string"
      paste(what, .str_encode(x, quote = "\""))
    },
    raw = paste("the raw value", as.character(x)),
    .rlang_stop_unexpected_typeof(x)
  )
}

.match_default_scalar <- function(x) {
  switch(typeof(x),
    logical = "a logical value",
    integer = "an integer",
    double = if (is.infinite(x)) .show_infinities(x) else "a number",
    complex = "a complex number",
    character = if (nzchar(x)) "a string" else "\"\"",
    raw = "a raw value",
    .rlang_stop_unexpected_typeof(x)
  )
}

.match_na_scalar <- function(x) {
  switch(typeof(x),
    logical = "`NA`",
    integer = "an integer `NA`",
    double =
      if (is.nan(x)) {
        "`NaN`"
      } else {
        "a numeric `NA`"
      },
    complex = "a complex `NA`",
    character = "a character `NA`",
    .rlang_stop_unexpected_typeof(x)
  )
}

.match_empty_object <- function(x) {
  switch(typeof(x),
    logical = "an empty logical vector",
    integer = "an empty integer vector",
    double = "an empty numeric vector",
    complex = "an empty complex vector",
    character = "an empty character vector",
    raw = "an empty raw vector",
    list = "an empty list",
    .rlang_stop_unexpected_typeof(x)
  )
}

vec_type_friendly <- function(x, length = FALSE) {
  if (!rlang::is_vector(x)) {
    rlang::abort("`x` must be a vector.")
  }
  type <- typeof(x)
  n_dim <- length(dim(x))

  if (type == "list") {
    return(.list_type_friendly(x, type, length, n_dim))
  }

  type <- .get_message_pattern(type)

  if (n_dim < 2) {
    kind <- "vector"
  } else if (n_dim == 2) {
    kind <- "matrix"
  } else {
    kind <- "array"
  }
  out <- sprintf(type, kind)

  if (n_dim >= 2) {
    out
  } else {
    .with_length(x, out, length, n_dim)
  }
}

.list_type_friendly <- function(x, type, length, n_dim) {
  if (n_dim < 2) {
    return(.with_length(x, "a list", length, n_dim))
  } else if (is.data.frame(x)) {
    return("a data frame")
  } else if (n_dim == 2) {
    return("a list matrix")
  } else {
    return("a list array")
  }
}

.with_length <- function(x, type, length, n_dim) {
  if (length && !n_dim) {
    paste0(type, sprintf(" of length %s", length(x)))
  } else {
    type
  }
}

.get_message_pattern <- function(type) {
  switch(type,
    logical = "a logical %s",
    integer = "an integer %s",
    numeric = ,
    double = "a double %s",
    complex = "a complex %s",
    character = "a character %s",
    raw = "a raw %s",
    type = paste0("a ", type, " %s")
  )
}

.rlang_as_friendly_type <- function(type) {
  switch(type,
    list = "a list",
    NULL = "`NULL`",
    environment = "an environment",
    externalptr = "a pointer",
    weakref = "a weak reference",
    S4 = "an S4 object",
    name = ,
    symbol = "a symbol",
    language = "a call",
    pairlist = "a pairlist node",
    expression = "an expression vector",
    char = "an internal string",
    promise = "an internal promise",
    ... = "an internal dots object",
    any = "an internal `any` object",
    bytecode = "an internal bytecode object",
    primitive = ,
    builtin = ,
    special = "a primitive function",
    closure = "a function",
    type
  )
}

.rlang_stop_unexpected_typeof <- function(x, call = rlang::caller_env()) {
  rlang::abort(
    sprintf("Unexpected type <%s>.", typeof(x)),
    call = call
  )
}

#' Return OO type
#' @param x Any R object.
#' @return One of `"bare"` (for non-OO objects), `"S3"`, `"S4"`,
#'   `"R6"`, or `"R7"`.
#' @noRd
obj_type_oo <- function(x) {
  if (!is.object(x)) {
    return("bare")
  }

  class <- inherits(x, c("R6", "R7_object"), which = TRUE)

  if (class[[1]]) {
    "R6"
  } else if (class[[2]]) {
    "R7"
  } else if (isS4(x)) {
    "S4"
  } else {
    "S3"
  }
}

#' @param x The object type which does not conform to `what`. Its
#'   `obj_type_friendly()` is taken and mentioned in the error message.
#' @param what The friendly expected type as a string. Can be a
#'   character vector of expected types, in which case the error
#'   message mentions all of them in an "or" enumeration.
#' @param show_value Passed to `value` argument of `obj_type_friendly()`.
#' @param ... Arguments passed to [abort()].
#' @inheritParams args_error_context
#' @noRd
stop_input_type <- function(x,
                            what,
                            ...,
                            allow_na = FALSE,
                            allow_null = FALSE,
                            show_value = TRUE,
                            arg = rlang::caller_arg(x),
                            call = rlang::caller_env()) {
  # From standalone-cli.R
  cli <- rlang::env_get_list(
    nms = c("format_arg", "format_code"),
    last = topenv(),
    default = function(x) sprintf("`%s`", x),
    inherit = TRUE
  )

  if (allow_na) {
    what <- c(what, cli$format_code("NA"))
  }
  if (allow_null) {
    what <- c(what, cli$format_code("NULL"))
  }
  if (length(what)) {
    what <- oxford_comma(what)
  }
  if (inherits(arg, "AsIs")) {
    format_arg <- identity
  } else {
    format_arg <- cli$format_arg
  }

  message <- sprintf(
    "%s must be %s, not %s.",
    format_arg(arg),
    what,
    obj_type_friendly(x, value = show_value)
  )

  rlang::abort(message, ..., call = call, arg = arg)
}

oxford_comma <- function(chr, sep = ", ", final = "or") {
  n <- length(chr)

  if (n < 2) {
    return(chr)
  }

  head <- chr[seq_len(n - 1)]
  last <- chr[n]

  head <- paste(head, collapse = sep)

  # Write a or b. But a, b, or c.
  if (n > 2) {
    paste0(head, sep, final, " ", last)
  } else {
    paste0(head, " ", final, " ", last)
  }
}

# nocov end
