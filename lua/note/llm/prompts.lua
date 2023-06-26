local copy = require('note.llm.copy')
local openai = require('llm.providers.openai')

return {
  summarize = {
    provider = openai,
    builder = function(input)
      return {
        messages = {
          {
            role = 'user',
            content = copy.instructions
          },
          {
            role = 'user',
            content = 'Notes: """\n' .. input .. '\n"""\n\nPlease summarize the notes.'
          }
        }
      }
    end,
    mode = 'buffer'
  }
}
