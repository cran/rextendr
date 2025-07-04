test_that("vendor_pkgs() vendors dependencies", {
  skip_if_not_installed("usethis")
  skip_on_cran()

  path <- local_package("testpkg")

  expect_error(vendor_pkgs(path))

  # capture setup messages
  withr::local_options(usethis.quiet = FALSE)
  use_extendr(path, quiet = TRUE)

  package_versions <- vendor_pkgs(path, quiet = TRUE)
  expect_snapshot(cat_file("src", "rust", "vendor-config.toml"))
  expect_snapshot(package_versions, transform = mask_any_version)
  expect_true(file.exists(file.path("src", "rust", "vendor.tar.xz")))
})


test_that("rextendr passes CRAN checks", {
  skip_if_not_installed("usethis")
  skip_if_not_installed("rcmdcheck")
  skip_on_cran()

  path <- local_package("testpkg")
  # write the license file to pass R CMD check
  usethis::use_mit_license()
  usethis::use_test("dummy", FALSE)
  use_extendr()
  vendor_pkgs()
  document()

  res <- rcmdcheck::rcmdcheck(
    env = c("NOT_CRAN" = ""),
    args = c("--no-manual", "--no-tests"),
    libpath = rev(.libPaths())
  )

  # --offline flag should be set
  expect_true(grepl("--offline", res$install_out))
  # -j 2 flag should be set
  expect_true(grepl("-j 2", res$install_out))

  # "Downloading" should not be present
  expect_false(grepl("Downloading", res$install_out))

  expect_length(res$errors, 0)
  expect_length(res$warnings, 0)
})
