# Add the following lines to _output.yml

#bookdown::markdown_document2:
#  base_format: rmarkdown::md_document
#  variant: markdown_strict+backtick_code_blocks+gfm_auto_identifiers+tex_math_single_backslash
#  pandoc_args: ["--markdown-headings=atx", "--reference-location=section"]
#  number_sections: false


# REGEX Patterns used to convert markdown syntax to kramdown (the format used in dodona)

title_pattern <- "^(#+)[[:space:]]+(\\S.*)$"
code_pattern <- "^\\s*```"
# regex pattern for html image tags (it is ignored if the path is an URL)
image_pattern_html <- "<img .*src=\"(?!http)([^\"]+)\"(.*)/>"
# regex pattern for markdown image tags, avoiding urls
image_pattern_md <- "!\\[\\]\\((?!http)([^\\(\\)]+)\\)"
image_pattern_md_url <- "!\\[\\]\\((?=http)([^\\(\\)]+)\\)"
caption_pattern <- "<p class=\"caption\"[^>]*>"
table_pattern <- "<table[^>]*>"
href_pattern <- "<a href=[^>]+>([[[:digit:]]\\.]+)</a>"
mdref_pattern <- "\\\\\\[[[:digit:]]+\\\\\\]"
inline_math_pattern <- "\\\\\\\\\\(|\\\\\\\\\\)"
math_open_pattern <- "^(.*?)\\\\\\\\\\[(.*)$"
math_close_pattern <- "^(.*?)\\\\\\\\\\](.*)$"
noNum_pattern <- "\\.unnumbered"
break_pattern <- "<!--+break--+>"


# push
push <- function(x, values) {
  assign(as.character(substitute(x)), c(x, values), parent.frame())
}

# pop
pop <- function(x) {
  value <- x[length(x)]
  assign(as.character(substitute(x)), x[-length(x)], parent.frame())
  value
}

write_section <- function(chapter_name, continuation = 0, i, lines, current_level, split_level, chapter_numbers, file_name, current_index, config, continue_str, noNum) {
  if (current_level < split_level) {
    # If we have content that is not at the deepest level of subsections
    # we make a '00' folder. This is so that the config files in Dodona dont conflict
    if (!file.exists('00')){
      dir.create('00')
    }
    setwd('00')
    push(chapter_numbers, 0)
  }
  if (!file.exists('description')){
    dir.create('description')
  }
  fileConn<-file(file.path("description", file_name), 'w')
  writeLines(lines[current_index:i-1], fileConn)
  close(fileConn)
  # If the config file doesnt exist yet, make one based on the template
  # If it does, read it in
  if (!file.exists('config.json')){
    config_new <- config
  } else {
    config_new <- jsonlite::read_json('config.json')
  }

  clean_chapter_name <- gsub(inline_math_pattern, "", chapter_name)

  if (noNum) {
    config_new$description$names$nl <- clean_chapter_name
  } else if (continuation > 0) {
    config_new$description$names$nl <- paste(paste(chapter_numbers, collapse = "."), " ", clean_chapter_name, " (", continue_str, " ", continuation, ")", sep = "")
  } else {
    config_new$description$names$nl <- paste(paste(chapter_numbers, collapse = "."), clean_chapter_name)
  }

  jsonlite::write_json(config_new, 'config.json', pretty = TRUE, auto_unbox = TRUE)
  if (current_level < split_level) {
    # If we made a '00' folder, we now have to move back up
    setwd('..')
    pop(chapter_numbers)
  }
}

copy_media <- function(media_path, file_path, subdir=F) {
  if (subdir) {
    media_path <- file.path("00", media_path)
  }
  if (!file.exists(media_path)){
    dir.create(media_path, recursive=T)
  }

  file.copy(from = file_path, to = media_path, overwrite = TRUE)
}
