(
  (string_content) @injection.content
  (#match? @injection.content "\n")
  (#set! injection.language "glsl")
)
