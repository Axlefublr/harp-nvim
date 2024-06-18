# harp.nvim

This plugin uses (and depends on) [harp](https://github.com/Axlefublr/harp) to make various improvements for file / directory navigation in neovim.

In this readme you can see an overview of all the features that the plugin provides.
For more details on the api provided, read the [source code](./lua/harp/init.lua), carefully commented to explain everything.
If you're interested in making the api documentation more solid, feel free to PR!

## Concept

Neovim uses the concept of registers in two ways: there are registers that store text, and registers that store file locations (marks).

We can use harp to take up the same concept, and store our own sets of paths and file locations, that are semantically different.

## Harps

The most barebones, but also most useful idea.

When you `:edit` a file, it gets automatically opened in the last place you were in, in the buffer.

So all we need to do is store file paths in registers.

Now, we can use a mapping to store the current buffer in a register.

And a different one to go `:edit` a buffer stored in that keyed register.

You can now jump to a bunch of different files really quickly! This is really useful for files you tend to edit most often, regardless of what your cwd is.

### Related api:

```lua
require('harp').default_get()
require('harp').default_set()
require('harp').default_get_path(register)
require('harp').default_set_path(register, path)
```

## Cwd Harps

Around 62 registers you will naturally have in default harps is already quite a lot, but as you use harp extensivelly you'll find they aren't enough.

Sometimes a certain file feels the best to be at some specific register, and moving it to another one is a bad tradeoff. I mean, you'll have edited more than 62 files eventually anyway!

So, cwd harps let you define harps _per project_. In other words, the registers you set are tied to your cwd (current working directory).

Now you have a set of files you can quickly jump to, that are specific to the project you're working on!

This is actually the main idea of [Harpoon](https://github.com/ThePrimeagen/harpoon), with the difference of storing paths in _registers_ rather than an indexed array.

### Related api:

```lua
require('harp').percwd_get()
require('harp').percwd_set()
require('harp').percwd_get_path(register, directory)
require('harp').percwd_set_path(register, directory, path)
```

## Local marks

If you've (tried) using built in neovim local marks, you might've seen the message "Mark is invalid".

Sometimes (usually due to formatters) the stored buffer position gets invalidated, because that position got changed. For some odd reason, neovim just fails, rather than trying to move you to the position it _still_ has stored.

Harp's "local marks" fix that!

You also get the extra benefit of being able to use not only lowercase letters for your "marks", but also uppercase letters, numbers, special symbols, and actually literally anything you can press. To my knowledge, even something like ctrl+f can be a valid register. This applies to every single feature in this plugin, btw. Each feature has a dedicated `feature_get` and `feature_set` function, and all of them use the same character getting mechanism. This is explained later in the readme.

### Related api:

```lua
require('harp').perbuffer_mark_get()
require('harp').perbuffer_mark_set()
require('harp').perbuffer_mark_get_location(register, path)
require('harp').perbuffer_mark_set_location(register, path, line, column)
```

## Global marks

Now _global_ built in neovim marks don't have any issues to my knowledge, and work perfectly.

The only benefit you get here is once again, more "marks" than just uppercase letters.

### Related api:

```lua
require('harp').global_mark_get()
require('harp').global_mark_set()
require('harp').global_mark_get_location(register)
require('harp').global_mark_set_location(register, path, line, column)
```

## Cd harps

This one is especially cool.

You use a mapping to store your current cwd in a register. Then you can use a different mapping to `:cd` into a directory stored in that register!

This allows you to jump between projects immensely quickly.

The full power of this is expanded if you also use [zoxide](https://github.com/ajeetdsouza/zoxide) in your shell, and then the [zoxide extension](https://github.com/jvgrootveld/telescope-zoxide) for [Telescope](https://github.com/nvim-telescope/telescope.nvim).

Fwiw, they become far less _needed_ with harp, but for the first, initial jump, using zoxide is pretty nice.

### Related api:

```lua
require('harp').cd_get()
require('harp').cd_set()
require('harp').cd_get_path(register)
require('harp').cd_set_path(register, directory)
```

## Positional harps

This one is the weirdest one, that I find **incredibly** useful regardless.

Think of all the times you create the same file structure in different projects, again and again. Almost every project will have a `.gitignore`. In rust projects, you'll end up wanting to go to `Cargo.toml` or `src/main.rs` very often. Heck, think about the `README.md`!

If you decide to use percwd harps for those, you'll have to set those harps again and again, as you create new projects. Additionally, you also have to go through the hassle of actually _creating_ the files first, and only then making a harp for them to be more accessible.

It's a hassle! Positional harps solve that :D

Positional harps just store the path of the current buffer, relative to your current working directory. Once you've saved one to a register, when you use it, you apply it relative to _whatever the current working directory is_. Let me give an example to clear things up.

Say you're working on a project and your current working directory is `~/prog/proj/harp`. You end up coming back to the readme file again and again, and so you decide to make it a positional harp. While your current buffer is `~/prog/proj/harp/README.md`, it gets saved as just `README.md` to the register of your choice.

Then, you decide to work on a different project and so you've changed your current working directory to `~/prog/proj/ghl`. You also want to edit the readme file there. You can use the register we just saved in harp!

In other words, we save just the path to the current buffer, so that we can use the same path to open relatively to any given cwd we're in. Positional harps exist for the files that appear in the same _project structure_, regardless of the project. While percwd harps are most useful for files that are _unique_ to a given project.

### Related api:

```lua
require('harp').positional_get()
require('harp').positional_set()
require('harp').positional_get_path(register)
require('harp').positional_set_path(register, path)
```

## Local search harps

The issue with marks, whether global or local, is that they can be invalidated. Invalidated simply because you moved some text around, and now the mark that you used to have points to the wrong place.

Search harps let you search for something, and save that search. Then, you can search for that saved search.

The workflow I had in mind when coming up with the feature is this: you have some section of your code that you want to be able to easily jump to. You search for it so that the search is unique. Now when you save that search, you have an ability to jump to that place even if it moves.

In other words, marks are best for when the position doesn't change (often) — setting a mark is going to be faster, because it just takes your position. Search harps are for when a position may move — you have to first make a search to set the harp, which is slower than setting a mark, but you get the benefit in that it will stay valid forever / longer.

### Related api:

```lua
require('harp').perbuffer_search_get(opts = {
	assume = false,
	from_start = false,
	restore = false,
	backwards = false,
	at_end = false
})
require('harp').perbuffer_search_set()
require('harp').perbuffer_search_get_pattern(register, path)
require('harp').perbuffer_search_set_pattern(register, path, pattern)
```

This is the first `_get()` function that takes arguments. They're explained in the source code, but I'll still go over them here. If you don't pass the opts table at all, all of the options will be disabled.

`assume` treats `/e` / `?e` at the end of the search pattern as a `:h search-offset`. Unfortunately only those are supported. The usual `+n` / `-n` after the search offset, and things like `/s` are not supported. By default (when `nil`), `/e` and `?e` at the end of a pattern are treated literally.

`from_start` searches from the start of the file, instead of from the current cursor position. Keep in mind, if the pattern does exist in the given register but a match was not found, you still will be moved to the start of the file.

`restore` the previous search. Say you searched for 'alisa', then used a search harp. With the flag off, when you press `n`, you would continue searching for the pattern in the search harp. With this flag on, you would continue searching for 'alisa'.

`backwards` search backwards, instead of forwards.

`at_end` puts the cursor at the end of the match, rather than the start. This is like using the `/e` search offset, but having this as your default might save you two keystrokes. Especially helpful for when you intend to use search harps mostly for their "mark-like" functionality, rather than just registers for searches.

## Global search harps

Like local search harps, but instead of being local to a buffer, are global.

First you jump to a file, and then attempt searching for a pattern. If the register is not set, you are not jumped to the file.

### Related api:

The `_get`'s function's `assume` and `at_end` parameters work like in `perbuffer_search_get`.

Unlike the local variant of search harps, global search harps always search from the top of the file, always restore your previous search, and cannot search backwards.

```lua
require('harp').global_search_get(assume, at_end)
require('harp').global_search_set()
require('harp').global_search_get_location(register)
require('harp').global_search_set_location(register, path, pattern)
```

## Filetype search harps

Instead of being relative to a buffer, they are relative to a filetype.

This way, you can effectively create arbitrary text objects per-language.

For example, I commonly want to jump and change over a rust function return type.

```rust
fn func(args) -> Result<(), Box<dyn Error>> {
	// code
}
```

Usually, it's pretty annoying. First, how do I get to the return type itself? Usually, I just scroll and use relative line jumping, but let's say I do the more smart thing and search for `->`. Then I need to `w` to end up on the actual return type. What then? Now to change over it, I could do:

1. `ct{` — that is a pretty good solution that I end up using, but it's annoying how it takes the space before the `{`
2. `cf>` — may sometimes work, but in the example above, it would need to be `c2f>`. And then, it might be 3 or 4 or whatever else! At which point it's too much counting to use comfortably.
3. `ct ` — can sometimes work, for types that don't take multiple generic arguments.

All of these solutions kinda suck ass. With filetype search harps, I can first search for this pattern: ` -> \zs.*\ze {` and now, I go directly to the return type, and _also_ have it as my latest search (if you keep the `restore` option off).

> `\zs` and `\ze` are probably the most useful vim regex thing you didn't know about. They let you completely circumvent having to use lookahead / lookbehinds, and are way simpler conceptually. I heavily recommend reading about them: `:h /\zs`, `:h /\ze` — they will massively improve your experience of using search harps (as well as usual searches / `:s` command / etc).

What this means is that now, I have the text object for the return type, and can access it with `gn`. So to finally change over the return type, I'd just do `cgn`.

The benefit of using ft search harps over _actual_ text objects:

1. Treesitter text objects specifically (in my experience) are hilariously slow. Searches aren't.
2. You don't have to spend time searching for plugins to get your hyperspecific text object.
3. You get to implement your own text objects, however specific they may be (this comes in hand with the previous point). As long as you can make up a vim regex pattern that catches what you're looking for, you get both the actions of "go to next / previous [blank]" and "act on this area" (meaning, text object, available through `gn`).
4. Installing a plugin or adding a text object in your configuration requires you to restart nvim to actually get the feature. With harp, you can set harps on the go, including search harps. So if you have some text object that would be really useful that you realize you want, you can just quickly make it into a ft search harp (or a buffer-local search harp, actually, depends on if it's language specifc or file specific) and then use it to finish your task. In the future, you can either continue using it or forget about it / override it with another pattern.

Don't get me wrong, if you want a text object for something as common as "value", "function", "argument", etc — there are plugins for that sort of thing, and you probably should be using them for that functionality (their matching is likely better than any vim regex pattern either you or me can ever come up with). But for something like "the keyword `local` but only if it's on the start of the line and is preceeded by a function definition" — yeah, that's a job for a search harp.

### Related api:

```lua
require('harp').filetype_search_get(opts = {
	assume = false,
	from_start = false,
	restore = false,
	backwards = false,
	at_end = false
})
require('harp').filetype_search_set()
require('harp').filetype_search_get_pattern(register, filetype)
require('harp').filetype_search_set_pattern(register, filetype, pattern)
```

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
	'Axlefublr/harp-nvim',
	lazy = true, -- your mappings will lazy load this plugin automatically. you'll find example mappings below in this readme.
	opts = {} -- makes sure the setup function is called, even though we don't provide any options so far.
}
```

## Setup

This plugin doesn't provide any default mappings. If you're an [AstroNvim](https://docs.astronvim.com) user though, there's a [community pack](https://github.com/AstroNvim/astrocommunity/tree/main/lua/astrocommunity/motion/harp-nvim) for it!

Each provided feature has 4 related functions you can use. Each feature heading in this readme includes the `Related api:` section, that lists the related functions.
Two of them are made for you to make direct mappings for. They're convenient because they automatically ask you for a character (to make you not have to make 62 separate mappings per every feature) and automatically use the correct paths in their implementation.
Their naming is, respectively, `feature_get` to _use_ a harp, and `feature_set` to _set_ a harp.

The second two functions exist to give you a way to access the feature more directly, and let you provide the register you want to act on, as well as the path you want to provide (for the `_set` functions). They are usually named as `feature_get_path` and `feature_set_path`.

### Suggested mappings

```lua
vim.keymap.set('n', '<Leader>i', function() require('harp').default_get() end)
vim.keymap.set('n', '<Leader>I', function() require('harp').default_set() end)

vim.keymap.set('n', '<Leader>x', function() require('harp').percwd_get() end)
vim.keymap.set('n', '<Leader>X', function() require('harp').percwd_set() end)

vim.keymap.set('n', '<Leader>r', function() require('harp').positional_get() end)
vim.keymap.set('n', '<Leader>R', function() require('harp').positional_set() end)

vim.keymap.set('n', "'", function() require('harp').perbuffer_mark_get() end)
vim.keymap.set('n', 'm', function() require('harp').perbuffer_mark_set() end)
vim.keymap.set('n', "'[", "'[") -- we do this to fix some useful default special marks
vim.keymap.set('n', "']", "']") -- because of the "'" mapping above
vim.keymap.set('n', "'<", "'<") -- if we forgot some of them, feel free to PR!
vim.keymap.set('n', "'>", "'>")
vim.keymap.set('n', "''", "''")
vim.keymap.set('n', "'^", "'^")

vim.keymap.set('n', "<Leader>'", function() require('harp').global_mark_get() end)
vim.keymap.set('n', '<Leader>m', function() require('harp').global_mark_set() end)

-- the mishmash of booleans here means: always appear at the end of the match, treat `/e` / `?e` at the end of a search pattern literally, and restore the previous search after using a local search harp
vim.keymap.set('n', '<Leader>t', function() require('harp').perbuffer_search_get({ assume = true }) end)
vim.keymap.set('n', '<Leader>T', function() require('harp').perbuffer_search_set() end
vim.keymap.set('n', '<Leader>/', function() require('harp').filetype_search_get({ assume = true }) end)
vim.keymap.set('n', '<Leader>?', function() require('harp').filetype_search_get({ assume = true, backwards = true }) end)
vim.keymap.set('n', '<Leader><Leader>/', function() require('harp').filetype_search_set() end)
vim.keymap.set('n', '<Leader>v', function() require('harp').global_search_get(false, true) end
vim.keymap.set('n', '<Leader>V', function() require('harp').global_search_set() end

vim.keymap.set('n', '<Leader>z', function() require('harp').cd_get() end)
vim.keymap.set('n', '<Leader>Z', function() require('harp').cd_set() end)
```

Because all of the mappings' right hand sides are `function`s, it makes the plugin automatically lazy load once you try to use one of the mappings.

Feel free to pick different mappings that make more sense in your setup!

## Utility Api

This is an overview of the remaining useful api that harp-nvim provides. For more details, look into the comments in the [source code](./lua/harp/init.lua).

You can use these utility functions along with the `_path` functions to define slightly different behavior for your mappings, if the default mapping functions don't fit your needs perfectly. For example, you could remake harp local marks to only use lowercase letters, and every other letter to be seen as a harp global mark.

```lua
require('harp').get_char(prompt)
```

Get a singular key from the user and return it. `nil` if the user presses escape (`<Esc>`).
Used throughout all the default harp-nvim mapping functions, to make you not have to make a billion separate mappings per every combination, and instead to only have to make one.

```lua
require('harp').split_by_newlines(string)
```

Get an array-like table containing each of the lines in a multiline text.

```lua
require('harp').path_get_full_buffer()
```

Returns the full path to the current buffer, but replaces `/home/username` with `~`.

`/home/username/prog/dotfiles/colors.css` → `~/prog/dotfiles/colors.css`

```lua
require('harp').path_get_cwd()
```

Returns your current working directory, but replaces `/home/username` with `~`.

`/home/username/prog/dotfiles` → `~/prog/dotfiles`

```lua
require('harp').path_get_relative_buffer()
```

Returns a path to the current buffer, that _can_ be relative to your current working directory.

For example, if your current working directory is `/home/username/prog/dotfiles` and your current buffer is `/home/username/prog/dotfiles/awesome/keys.lua`, you will get `awesome/keys.lua`. So, it is relative to dotfiles in this case.

However, if the current buffer is the same, but the _current working directory_ is `/home/username/prog/backup` instead, you'd get `~/prog/dotfiles/awesome/keys.lua`. In other words, if your current buffer is **not** inside of your current working directory, you get the full path to the buffer, equivalent to the output of `path_get_full_buffer()`.
