test_that("knitr-engine works", {
  skip_if_cargo_unavailable()
  skip_if_not_installed("knitr")
  skip_on_cran()

  options <- knitr::opts_chunk$merge(list(
    code = "2 + 2",
    comment = "##",
    eval = TRUE,
    echo = TRUE
  ))

  expect_equal(eng_extendr(options), "2 + 2\n## [1] 4\n")

  options <- knitr::opts_chunk$merge(list(
    code = "rprintln!(\"hello world!\");",
    comment = "##",
    eval = TRUE,
    echo = FALSE
  ))

  expect_equal(eng_extendr(options), "## hello world!\n")
})


test_that("Snapshot test of knitr-engine", {
  skip_if_cargo_unavailable()
  skip_if_not_installed("knitr")
  skip_on_cran()

  input <- file.path("../data/test-knitr-engine-source-01.Rmd")
  output <- withr::local_file("snapshot_knitr_test.md")

  knitr::knit(input, output)
  expect_snapshot(cat_file(output))
})
