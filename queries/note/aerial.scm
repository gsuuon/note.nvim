(section
  ((section_header) @name) @level
  (#set! "kind" "Interface")
  (#gsub! @name "#+ (.*)" "%1")
  ) @symbol
