# Test if `pretty_rel_path` determines relative paths correctly.
# Edge cases include initiating the search from a directory outside of
# package directory (an ancestor/parent in the hierarchy), and
# from a non-existent/invalid directory (such as `NA` or `""`),
# in which case `pretty_rel_path` should return absolute path of itr
# first argument.
test_that("Find relative path from package root, trivial case", {
  skip_if_not_installed("usethis")

  pkg_root <- local_package("testpkg")
  use_extendr()

  expect_equal(
    pretty_rel_path(
      file.path(pkg_root, "R", "extendr-wrappers.R"),
      pkg_root
    ),
    "R/extendr-wrappers.R"
  )
})

test_that("Find relative path starting from a subdirectory of package", {
  skip_if_not_installed("usethis")

  pkg_root <- local_package("testpkg")
  use_extendr()

  expect_equal(
    pretty_rel_path(
      file.path(pkg_root, "R", "extendr-wrappers.R"),
      file.path(pkg_root, "src", "rust", "src", "lib.rs")
    ),
    "R/extendr-wrappers.R"
  )
})

test_that("Find relative path starting outside of package directory, return absolute path", {
  skip_if_not_installed("usethis")

  pkg_root <- local_package("testpkg")
  use_extendr()


  expect_equal(
    pretty_rel_path(
      file.path(pkg_root, "R", "extendr-wrappers.R"),
      file.path(pkg_root, "..")
    ),
    normalizePath(
      file.path(pkg_root, "R", "extendr-wrappers.R"),
      winslash = "/"
    )
  )
})

test_that("Find relative path providing no input for the package directory, return absolute path", {
  skip_if_not_installed("usethis")

  pkg_root <- local_package("testpkg")
  use_extendr()

  expect_equal(
    pretty_rel_path(
      file.path(pkg_root, "R", "extendr-wrappers.R"),
      ""
    ),
    normalizePath(
      file.path(pkg_root, "R", "extendr-wrappers.R"),
      winslash = "/"
    )
  )
})

test_that("Find relative path providing NA as input for the package directory, return absolute path", {
  skip_if_not_installed("usethis")

  pkg_root <- local_package("testpkg")
  use_extendr()

  expect_equal(
    pretty_rel_path(
      file.path(pkg_root, "R", "extendr-wrappers.R"),
      NA_character_
    ),
    normalizePath(
      file.path(pkg_root, "R", "extendr-wrappers.R"),
      winslash = "/"
    )
  )
})

test_that(
  "Find relative path providing empty character vector as input for the package directory, return absolute path",
  {
    skip_if_not_installed("usethis")

    pkg_root <- local_package("testpkg")
    use_extendr()

    expect_equal(
      pretty_rel_path(
        file.path(pkg_root, "R", "extendr-wrappers.R"),
        character(0)
      ),
      normalizePath(
        file.path(pkg_root, "R", "extendr-wrappers.R"),
        winslash = "/"
      )
    )
  }
)

test_that("Test path to non-existent file", {
  skip_if_not_installed("usethis")

  pkg_root <- local_package("testpkg")
  use_extendr()

  expect_equal(
    pretty_rel_path(
      file.path(pkg_root, "A", "B", "C", "D.F"),
      pkg_root
    ),
    "A/B/C/D.F"
  )
})
