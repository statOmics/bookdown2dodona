
#' Compile bookdown formatted markdown to a Dodona-ready format
#'
#' The compileB2D function can be used to compile a set of Rmarkdown files
#' that follow the bookdown standard to a folder structure of description files that can be directly used with Dodona.
#'
#'
#' @param source_dir (optional) Path to the directory containing the bookdown source files. Default is current working directory.
#' @param output_dir (optional) Path to the directory where the Dodona file structure will be saved. Default is './dodona_md'
#' @param book_dir (optional) Name of the directory where the complete book will be saved as an .md file. This directory will be placed in the source directory. Default is 'book_md'
#' @param language (optional) Language identifier string that is used to tell Dodona which language the descriptions are in. Default is 'nl'.
#' @param split_level (optional) Level of markdown headers at which chapters will be split in Dodona reading assignments. Default is 2, corresponding to '##' headers.
#' @param continue_str (optional) String that is used to indicate the continuation of a chapter when section breaks (<!--break-->) are used. Default is 'Vervolg'.
#' @param config_file (optional) Name of the configuration file used by bookdown. Default is '_bookdown.yml'
#'
#'
#' @examples
#' #compileB2D()
#' #compileB2D('./myBookdownProject', output_dir='myDodonaBook', book_dir='myFullBook')
#'
#' @export
compileB2D <- function(source_dir = '.', output_dir = './dodona_md', book_dir = 'book_md', language = 'nl', split_level = 2, continue_str = 'Vervolg', config_file = '_bookdown.yml') {
  description_file_name <- paste0('description.', language, '.md')
  media_path <- file.path('description', 'media')
  yml <- yaml::read_yaml(file.path(source_dir,config_file))

  source_dir = normalizePath(source_dir)

  # If no filename is specified in _bookdown.yml, a default name is used
  if (is.null(yml$book_filename)) {
    name <- '_main'
  } else {
    name <- yml$book_filename
  }

  # Render the full book into the book_dir directory
  base_wd <- getwd()
  setwd(source_dir)
  bookdown::render_book("", output_format = "bookdown::markdown_document2", clean=T, output_dir = book_dir, config_file = config_file)

  # Read the lines of the resulting book into `lines`
  lines <- readLines(file.path(book_dir,paste0(name, '.md')))

  # Construct the json config template
  config <- list(type = "content",
                 description = list(names = list(language = 'temp')),
                 access = "public",
                 labels = list())

  setwd(base_wd)

  if (!file.exists(output_dir)){
    dir.create(output_dir, recursive=T)
  }
  setwd(output_dir)

  line_type <- 'text'       #whether we are in a text or code block
  current_level <- 0        #current section depth
  current_index <- 1        #index of first line in 'lines' that has not been written to a file yet
  content_found <- FALSE    #True if non-empty line has been found in current section (avoids creating empty files)
  noNum <- FALSE            #True if current section is .unnumbered
  continuation <- 0         #Keeps track of current continuation when using <!--break--> tags
  i <- 1
  # Chapter numbers will be kept in a push/pop stack
  chapter_numbers <- numeric(0)
  chapter_name <- ""

  print("Splitting the output file ...")
  while(i <= length(lines)) {
    if (i %% 100 == 0){
      print(i)
    }
    line <- lines[i]
    if (line_type == 'text') {

      # check if the current line contains a header
      title_match <- stringr::str_match(line, title_pattern)
      # check if there is any non-whitespace
      white_match <- stringr::str_match(line, "\\S")

      if (!is.na(title_match[1])) {
        # Title level is the number of #'s at the start of the line.
        # The string of #'s is captured in match[2]
        title_level <- nchar(title_match[2])

        # If the title level is <= the split level we end the current file and start a new one
        if (title_level <= split_level) {
          previous_chapter <- chapter_name
          # Get the chapter name from the header, removing the markdown header annotations
          chapter_name <- sub("\\s*\\{.*\\}", "",title_match[3])
          # If content was found in previous chapter -> write it to a file
          if (content_found) {
            write_section(previous_chapter, continuation, i, lines, current_level, split_level, chapter_numbers, description_file_name, current_index, config, continue_str, noNum)
            # If non-numbered chapter, reduce chapter number by 1 to skip numbering
            if (noNum) {
              num <- pop(chapter_numbers)
              push(chapter_numbers, num-1)
              noNum <- FALSE
            }
            current_index <- i
            content_found <- FALSE
            continuation <- 0
          }
          # If title is of a lower level -> make dir and step into it.
          # This will always be subsection number 1
          level_diff <- title_level - current_level
          if (level_diff >= 1){
            # If we skip a number of levels, we make a subdirectory for each level to remain consistent.
            if (level_diff > 1){
              steps <- level_diff - 1
              for (j in 1:steps){
                if (!file.exists('0')){
                  dir.create('0')
                }
                setwd('0')
              }
            }
            dirname <- stringr::str_replace_all(chapter_name, "[[:punct:]]", "")
            if (!file.exists(dirname)){
              dir.create(dirname)
            }
            setwd(dirname)
            if (file.exists(media_path)){
              unlink(media_path, recursive = TRUE)
            }
            push(chapter_numbers, 1)

          } else if (level_diff < 1) {
            steps <- 1 - level_diff
            # Go back up in file structure and pop chapter_numbers to check where we were
            for (j in 1:steps){
              setwd('..')
              chapter <- pop(chapter_numbers)
            }
            chapter <- chapter + 1
            # Remove punctuation to create a valid directory name
            dirname <- stringr::str_replace_all(chapter_name, "[[:punct:]]", "")
            if (!file.exists(dirname)){
              dir.create(dirname)
            }
            setwd(dirname)
            if (file.exists(media_path)){
              unlink(media_path, recursive = TRUE)
            }
            push(chapter_numbers, chapter)
          } else {
            print(paste('Title structure is incorrect at line: ', toString(i)))
          }
          current_level <- title_level
        } else{
          content_found <- TRUE
        }
      } else if (!is.na(white_match[1])) {
        # If line is not a new header and contains non-whitespace characters, set content_found to TRUE
        content_found <- TRUE
      }

      if (!is.na(white_match[1])) {

        # check if a code block starts
        code_block_match <- stringr::str_match(line, "^[[:space:]]*```")

        # Here we check for a set of patterns that must be manually altered to be displayed correctly in Dodona

        if (!is.na(code_block_match[1])) {
          # Set line type to code so lines inside a codeblock are ignored when looking for headers
          line_type <- 'code'
        } else {

          # If HTML image tag found, copy file and replace path in lines[i]
          image_match_html <- stringr::str_match(lines[i], image_pattern_html)
          if(!is.na(image_match_html[1])) {
            file_path <- file.path(source_dir, "_bookdown_files" , image_match_html[2])
            copy_media(media_path, file_path, subdir=current_level < split_level)
            lines[i] <- paste("<img src=\"", file.path('media',basename(image_match_html[2])),"\" width=\"70%\" style=\"display: block; margin: auto;\" />", sep = "")
          }

          # If MD image tag found, copy file and replace with an HTML tag in lines[i]
          image_match_md <- stringr::str_match(lines[i], image_pattern_md)
          if(!is.na(image_match_md[1])) {
            file_path <- file.path(source_dir, "_bookdown_files" , image_match_md[2])
            copy_media(media_path, file_path, subdir=current_level < split_level)
            lines[i] <- paste("<img src=\"", file.path('media',basename(image_match_md[2])),"\" width=\"70%\" style=\"display: block; margin: auto;\" />", sep = "")
          }

          # If MD URL image tag found, replace with an HTML tag in lines[i]
          image_match_md_url <- stringr::str_match(lines[i], image_pattern_md_url)
          if(!is.na(image_match_md_url[1])) {
            lines[i] <- paste("<img src=\"",image_match_md_url[2],"\" width=\"70%\" style=\"display: block; margin: auto;\" />", sep = "")
          }

          # If a caption is found, add 'style="text-align:center"' to use center the caption
          caption_match <- stringr::str_match(lines[i], caption_pattern)
          if(!is.na(caption_match[1])) {
            lines[i] <- sub("<p class=\"caption\"", "<p class=\"caption\" style=\"text-align:center\"", lines[i])
          }

          # If a table is found, add 'class=table' to use Dodona table style
          table_match <- stringr::str_match(lines[i], table_pattern)
          if(!is.na(table_match[1])) {
            lines[i] <- sub("<table", "<table class=\"table\"", lines[i])
          }

          # When a header attribute {.unnumbered} is found, set noNum to TRUE
          noNum_match <- stringr::str_match(lines[i], noNum_pattern)
          if(!is.na(noNum_match[1])) {
            noNum <- TRUE
          }

          if(!is.na(title_match[1])) {
            lines[i] <- sub("\\s*\\{.*\\}", "",lines[i])
          }

          # Replace clickable link with bold text since the link doesn't work in Dodona
          href_match <- stringr::str_match(lines[i], href_pattern)
          if (!is.na(href_match[1])) {
            lines[i] <- gsub("<a href=[^>]+>", "**", lines[i])
            lines[i] <- gsub("</a>", "**", lines[i])
          }

          # Inline math using \(...\) is replaced with $$...$$
          inline_math_match <- stringr::str_match(lines[i], inline_math_pattern)
          if(!is.na(inline_math_match[1])) {
            lines[i] <- gsub(inline_math_pattern, "$$", lines[i])
          }

          # Equations that are not inline need to be surrounded by empy lines in Dodona. We insert empty lines if this is not the case.
          math_open_match <- stringr::str_match(lines[i], math_open_pattern)
          if (!is.na(math_open_match[1])) {
            if (math_open_match[2] != "") {
              lines <- append(lines, math_open_match[2], i-1)
              i = i+1
            }
            if (lines[i-1] != "") {
              lines <- append(lines, "", i-1)
              i = i+1
            }
            lines[i] <- paste("$$",math_open_match[3], sep="")
          }

          math_close_match <- stringr::str_match(lines[i], math_close_pattern)
          if (!is.na(math_close_match[1])) {
            if (math_close_match[3] != "") {
              lines <- append(lines, math_close_match[3], i)
            }
            if (lines[i+1] != "") {
              lines <- append(lines, "", i)
            }
            lines[i] <- paste(math_close_match[2], "$$", sep="")
          }

          # When a section break is found, write previous section and create a new directory for the continuation section
          break_match <- stringr::str_match(line, break_pattern)
          if(!is.na(break_match[1])) {
            write_section(chapter_name, continuation, i, lines, current_level, split_level, chapter_numbers, description_file_name, current_index, config, continue_str, noNum)
            continuation <- continuation + 1
            current_index <- i+1
            setwd('..')
            dirname <- paste(stringr::str_replace_all(chapter_name, "[[:punct:]]", ""), continue_str, continuation)
            if (!file.exists(dirname)){
              dir.create(dirname)
            }
            setwd(dirname)
          }
        }
      }
    # If line type is not text, it means we are in a code block
    } else {
      # check if code block ends
      code_block_match <- stringr::str_match(line, "^[[:space:]]*```")
      if (!is.na(code_block_match[1])) {
        line_type <- 'text'
      }
    }
    i <- i+1
  }
  # Write the last section
  write_section(chapter_name, continuation, i, lines, current_level, split_level, chapter_numbers, description_file_name, current_index, config, continue_str, noNum)
  # Go back to original working directory
  setwd(base_wd)
}


