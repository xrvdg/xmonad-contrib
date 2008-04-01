{- |
 Module      :  XMonad.Actions.Search
 Copyright   :  (C) 2007 Gwern Branwen
 License     :  None; public domain

 Maintainer  :  <gwern0@gmail.com>
 Stability   :  unstable
 Portability :  unportable

 A module for easily running Internet searches on web sites through xmonad.
 Modeled after the handy Surfraw CLI search tools at <https://secure.wikimedia.org/wikipedia/en/wiki/Surfraw>.

 Additional sites welcomed.
-}
module XMonad.Actions.Search (    -- * Usage
                                  -- $usage
                               search,
                               simpleEngine,
                               promptSearch,
                               promptSearchBrowser,
                               selectSearch,
                               selectSearchBrowser,

                               amazon,
                               google,
                               hoogle,
                               imdb,
                               maps,
                               mathworld,
                               scholar,
                               wayback,
                               wikipedia

                                  -- * Use case: searching with a submap
                                  -- $tip

                          ) where

import Data.Char (chr, ord, isAlpha, isMark, isDigit)
import Numeric (showIntAtBase)
import XMonad (X(), MonadIO, liftIO)
import XMonad.Prompt (XPrompt(showXPrompt), mkXPrompt, XPConfig())
import XMonad.Prompt.Shell (getBrowser, getShellCompl)
import XMonad.Util.Run (safeSpawn)
import XMonad.Util.XSelection (getSelection)

{- $usage

   This module is intended to allow easy access to databases on the
   Internet through xmonad's interface. The idea is that one wants to
   run a search but the query string and the browser to use must come
   from somewhere. There are two places the query string can come from
   - the user can type it into a prompt which pops up, or the query
   could be available already in the X Windows copy\/paste buffer
   (perhaps you just highlighted the string of interest).

   Thus, there are two main functions: 'promptSearch', and
   'selectSearch' (implemented using the more primitive 'search'). To
   each of these is passed an engine function; this is a function that
   knows how to search a particular site.

   For example, the 'google' function knows how to search Google, and
   so on. You pass 'promptSearch' and 'selectSearch' the engine you
   want, the browser you want, and anything special they might need;
   this whole line is then bound to a key of you choosing in your
   xmonad.hs. For specific examples, see each function.  This module
   is easily extended to new sites by using 'simpleEngine'.

   The currently available search engines are:

* 'amazon' -- Amazon keyword search.

* 'google' -- basic Google search.

* 'hoogle' -- Hoogle, the Haskell libraries search engine.

* 'imdb'   -- the Internet Movie Database.

* 'maps'   -- Google maps.

* 'mathworld' -- Wolfram MathWorld search.

* 'scholar' -- Google scholar academic search.

* 'wayback' -- the Wayback Machine.

* 'wikipedia' -- basic Wikipedia search.

Feel free to add more! -}

{- $tip

In combination with "XMonad.Actions.Submap" you can create a powerful
and easy way to search without adding a whole bunch of bindings.

First import the necessary modules:

> import qualified XMonad.Prompt         as P
> import qualified XMonad.Actions.Submap as SM
> import qualified XMonad.Actions.Search as S

Then add the following to your key bindings:

> ...
> -- Search commands
> , ((modm, xK_s), SM.submap $ searchEngineMap $ S.promptSearch P.defaultXPConfig)
> , ((modm .|. shiftMask, xK_s), SM.submap $ searchEngineMap $ S.selectSearch)
>
> ...
>
> searchEngineMap method = M.fromList $
>       [ ((0, xK_g), method S.google)
>       , ((0, xK_h), method S.hoogle)
>       , ((0, xK_w), method S.wikipedia)
>       ]

Make sure to set firefox to open new pages in a new window instead of
in a new tab: @Firefox -> Edit -> Preferences -> Tabs -> New pages
should be opened in...@

Now /mod-s/ + /g/\//h/\//w/ prompts you for a search string, then
opens a new firefox window that performs the search on Google, Hoogle
or Wikipedia respectively.

If you select something in whatever application and hit /mod-shift-s/ +
/g/\//h/\//w/ it will search the selected string with the specified
engine.

Happy searching! -}

-- | A customized prompt indicating we are searching, and not anything else.
data Search = Search
instance XPrompt Search where
    showXPrompt Search = "Search: "

-- | Escape the search string so search engines understand it.
-- Note that everything is escaped; we could be smarter and use 'isAllowedInURI'
-- but then that'd be hard enough to copy-and-paste we'd need to depend on @network@.
escape :: String -> String
escape = escapeURIString (\c -> isAlpha c || isDigit c || isMark c)
         where -- Copied from Network.URI.
           escapeURIString ::
               (Char -> Bool)      -- a predicate which returns 'False' if should escape
               -> String           -- the string to process
               -> String           -- the resulting URI string
           escapeURIString p s = concatMap (escapeURIChar p) s
           escapeURIChar :: (Char->Bool) -> Char -> String
           escapeURIChar p c
               | p c       = [c]
               | otherwise = '%' : myShowHex (ord c) ""
               where
                 myShowHex :: Int -> ShowS
                 myShowHex n r =  case showIntAtBase 16 (toChrHex) n r of
                                    []  -> "00"
                                    [ch] -> ['0',ch]
                                    cs  -> cs
                 toChrHex d
                   | d < 10    = chr (ord '0' + fromIntegral d)
                   | otherwise = chr (ord 'A' + fromIntegral (d - 10))

type Browser      = FilePath
type Query        = String
type SearchEngine = String -> String

-- | Given a browser, a search engine, and a search term, perform the
--   requested search in the browser.
search :: Browser -> SearchEngine -> Query -> X ()
search browser site query = safeSpawn browser $ site query

{- | Given a base URL, create the SearchEngine that escapes the query and
   appends it to the base. You can easily define a new engine locally using simpleEngine
   without needing to modify Search.hs:

   > newEngine = simpleEngine "http://site.com/search="

   The important thing is that the site has a interface which accepts the query
   string as part of the URL. Alas, the exact URL to feed simpleEngine varies
   from site to site, often considerably. Generally, examining the resultant URL
   of a search will allow you to reverse-engineer it if you can't find the
   necessary URL already described in other projects such as Surfraw. -}
simpleEngine :: Query -> SearchEngine
simpleEngine site query = site ++ escape query

-- The engines.
amazon, google, hoogle, imdb, maps, mathworld, scholar, wayback, wikipedia :: SearchEngine
amazon    = simpleEngine "http://www.amazon.com/exec/obidos/external-search?index=all&keyword="
google    = simpleEngine "http://www.google.com/search?num=100&q="
hoogle    = simpleEngine "http://www.haskell.org/hoogle/?q="
imdb      = simpleEngine "http://www.imdb.com/Find?select=all&for="
maps      = simpleEngine "http://maps.google.com/maps?q="
mathworld = simpleEngine "http://mathworld.wolfram.com/search/?query="
scholar   = simpleEngine "http://scholar.google.com/scholar?q="
wikipedia = simpleEngine "https://secure.wikimedia.org/wikipedia/en/wiki/Special:Search?go=Go&search="
{- This doesn't seem to work, but nevertheless, it seems to be the official
   method at <http://web.archive.org/collections/web/advanced.html> to get the
   latest backup. -}
wayback   = simpleEngine "http://web.archive.org/"

{- | Like 'search', but for use with the output from a Prompt; it grabs the
   Prompt's result, passes it to a given searchEngine and opens it in a given
   browser. -}
promptSearchBrowser :: XPConfig -> Browser -> SearchEngine -> X ()
promptSearchBrowser config browser engine = mkXPrompt Search config (getShellCompl []) $ search browser engine

{- | Like 'search', but in this case, the string is not specified but grabbed
 from the user's response to a prompt. Example:

> , ((modm, xK_g), promptSearch greenXPConfig google)

   This specializes "promptSearchBrowser" by supplying the browser argument as
   supplied by 'getBrowser' from "XMonad.Prompt.Shell". -}
promptSearch :: XPConfig -> SearchEngine -> X ()
promptSearch config engine = liftIO getBrowser >>= \ browser -> promptSearchBrowser config browser engine

-- | Like 'search', but for use with the X selection; it grabs the selection,
--   passes it to a given searchEngine and opens it in a given browser.
-- selectSearchBrowser :: Browser -> SearchEngine -> IO ()
selectSearchBrowser :: Browser -> SearchEngine -> X ()
selectSearchBrowser browser searchengine = search browser searchengine =<< getSelection

{- | Like 'search', but for use with the X selection; it grabs the selection,
   passes it to a given searchEngine and opens it in the default browser . Example:

> , ((modm .|. shiftMask, xK_g), selectSearch google)

   This specializes "selectSearchBrowser" by supplying the browser argument as
   supplied by 'getBrowser' from "XMonad.Prompt.Shell". -}
selectSearch :: SearchEngine -> X ()
selectSearch engine = liftIO getBrowser >>= \browser -> selectSearchBrowser browser engine