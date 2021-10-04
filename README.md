# bookdown2dodona
Bookdown2dodona can compile books developed in R/bookdown to the interactive learning environment Dodona.

# Dependencies
bookdown2dodona has been tested to work with following software versions:

- [Pandoc](https://pandoc.org/): 2.11.3
- [Bookdown](https://bookdown.org/): 0.21
- [Rmarkdown](https://rmarkdown.rstudio.com/): 2.5
- yaml: 2.2
- jsonlite: 1.7

Make sure to update your Pandoc, Bookdown and Rmarkdown packages as older versions of these packages are known to be incompatible with bookdown2dodona.

# Installation

The easiest way to install boodown2dodona is to use the 'devtool' package
``` r
library(devtools)
install_github("statOmics/bookdown2dodona")
```

# Usage

By default, bookdown2dodona will look for bookdown files in your current working directory. The compilation itself is done by using the `compileB2D` function.

``` r
library(bookdown2dodona)
setwd('/path/to/your/bookdown/files/')
compileB2D()
```

This will place the compiled book in a folder named `book_md` and the Dodona files in `Dodona_md`.

Alternatively, the source and output directories can be defined manually.
Some other examples:
``` r
compileB2D(source_dir='your/bookdown/files/', output_dir='your/dodona/files/')
compileB2D(source_dir='your/bookdown/files/', output_dir='your/dodona/files/', language='en', split_level=3, continue_str="Continued")
```

# Notes for developing in Bookdown

## setup
Add the following lines to `_output.yml`:
``` yml
bookdown::markdown_document2:
  base_format: rmarkdown::md_document
  variant: markdown_strict+backtick_code_blocks+gfm_auto_identifiers+tex_math_souble_backslash+header_attributes
  pandoc_args: ["--markdown-headings=atx", "--reference-location=document", "--wrap=preserve"]
  number_sections: false
```

## breaks
If you want to manually subdivide a long section into multiple Dodona assignments you can add breaks by inserting the

``` html
<!--break-->
```

html comment into your Rmarkdown file.

## Images

Images (either html or md format) must be on a seperate line in your Rmd file.

Scaling of images is hardcoded at 70% width to make sure they look good in Dodona.
If you need a smaller image, the easiest solution is to add white borders around the image so it looks good at 70% scaling.
