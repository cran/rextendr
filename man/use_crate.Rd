% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/use_crate.R
\name{use_crate}
\alias{use_crate}
\title{Add dependencies to a Cargo.toml manifest file}
\usage{
use_crate(
  crate,
  features = NULL,
  git = NULL,
  version = NULL,
  optional = FALSE,
  path = ".",
  echo = TRUE
)
}
\arguments{
\item{crate}{character scalar, the name of the crate to add}

\item{features}{character vector, a list of features to include from the
crate}

\item{git}{character scalar, the full URL of the remote Git repository}

\item{version}{character scalar, the version of the crate to add}

\item{optional}{boolean scalar, whether to mark the dependency as optional
(FALSE by default)}

\item{path}{character scalar, the package directory}

\item{echo}{logical scalar, should cargo command and outputs be printed to
console (default is TRUE)}
}
\value{
\code{NULL} (invisibly)
}
\description{
Analogous to \code{usethis::use_package()} but for crate dependencies.
}
\details{
For more details regarding these and other options, see the
\href{https://doc.rust-lang.org/cargo/commands/cargo-add.html}{Cargo docs}
for \code{cargo-add}.
}
\examples{
\dontrun{
# add to [dependencies]
use_crate("serde")

# add to [dependencies] and [features]
use_crate("serde", features = "derive")

# add to [dependencies] using github repository as source
use_crate("serde", git = "https://github.com/serde-rs/serde")

# add to [dependencies] with specific version
use_crate("serde", version = "1.0.1")

# add to [dependencies] with optional compilation
use_crate("serde", optional = TRUE)
}
}
