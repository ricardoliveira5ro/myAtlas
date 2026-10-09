# IDEA.md

# Project Idea --- My Atlas

## 1. Product Overview

### 1.1 Concept

This project is a visual and social travel archive centered around an
interactive representation of the world.

The core idea is simple:

> **A map of the world that becomes a visual representation of the
> places a person has experienced.**

Users can record the countries and cities they have visited, preserve
memories and photographs associated with those places, explore
statistics and facts about their travels, and share their travel profile
with friends.

The product should feel like a **personal travel world** rather than a
checklist of countries.

The map is the central experience and the primary entry point. Users
should be able to visually explore their own travel history by zooming
from the world into countries and then into cities.

The product is deliberately **not intended to become another
Instagram**, a general-purpose social network, or a travel
booking/planning platform.

Its primary purpose is:

1.  Preserve travel experiences.
2.  Visually represent where the user has been.
3.  Make those experiences enjoyable to explore.
4.  Allow users to share their travel history with friends.
5.  Allow friends to discover overlaps and differences in their travel
    experiences.
6.  Give users a sense of progression as their world expands.

------------------------------------------------------------------------

# 2. Product Philosophy

## 2.1 The emotional problem

People accumulate travel photographs, itineraries, reservations, notes
and memories over the years, but these experiences become fragmented
across:

-   phone galleries
-   cloud storage
-   social media
-   PDFs
-   emails
-   messaging conversations
-   notes
-   booking websites
-   physical documents

The result is that a person's travel history exists, but it is difficult
to experience as a coherent whole.

A photo gallery contains photographs, but does not necessarily
communicate:

> Where was I?

> How many times have I been there?

> What cities have I experienced?

> How much of the world have I seen?

> What did this country mean to me?

> Which places have my friends also visited?

This product aims to create a dedicated home for that information.

------------------------------------------------------------------------

## 2.2 The core emotional proposition

The product should make users feel:

> **"This is my world."**

The world map should progressively become personalized as the user
records more places.

A new user may initially have only a few countries highlighted.

Over time, the map becomes increasingly populated.

The visual progression itself should be rewarding.

The product should make the user want to return after every trip simply
because they have a new place to add and new memories to preserve.

------------------------------------------------------------------------

## 2.3 What the product is NOT

The product should deliberately avoid becoming:

-   an Instagram clone
-   a generic social network
-   a travel booking platform
-   a flight tracker
-   a travel itinerary planner
-   a recommendation engine
-   a generic photo-storage service
-   a public influencer platform
-   a feed-driven social media application
-   a platform where popularity and engagement metrics dominate the
    experience

There should be no requirement for users to constantly publish content.

The user's travel history belongs to them.

Social functionality exists to make the archive more interesting and
shareable, not to turn the application into an engagement-driven social
network.

------------------------------------------------------------------------

# 3. Core Experience

The core navigation hierarchy is:

**World → Country → City**

The user should be able to move naturally through this hierarchy.

The map is the entry point.

A user starts at the world level and can:

1.  Explore the globe/map.
2.  Zoom into a region.
3.  Select a country.
4.  Open that country's overview.
5.  Explore cities associated with that country.
6.  Select a city.
7.  Explore the user's memories, photographs, statistics and information
    about that city.

There is intentionally **no first-class Trip concept in the initial
product definition**.

A user may have visited a country or city many times, but the primary
organization is based on **place**, not individual journeys.

This keeps the product focused on the permanent relationship between the
user and a location.

------------------------------------------------------------------------

# 4. Home Screen / World Map

## 4.1 The map is the product's primary entry point

The home screen should immediately present the user's world.

The map/globe should occupy the dominant visual space.

The user should be able to:

-   rotate the globe, if using a globe representation
-   zoom in
-   zoom out
-   move around the world
-   identify visited countries
-   select countries
-   navigate into country pages

The experience should be visually attractive enough that simply
exploring the map is enjoyable.

------------------------------------------------------------------------

## 4.2 Visited countries

Visited countries should have a visually distinct state.

A visited country should be clearly recognizable as belonging to the
user's travel history.

The exact visual treatment can evolve, but the core principle is:

> **The user's visited countries are visually different from the rest of
> the world.**

The map should make it immediately possible to answer:

> "Where have I been?"

without opening statistics or lists.

------------------------------------------------------------------------

## 4.3 Non-visited countries

Countries that the user has not marked as visited should remain visually
distinct from visited countries.

They should still exist as part of the world map and remain explorable
where appropriate.

This creates a natural contrast between:

-   places experienced
-   places not yet experienced

------------------------------------------------------------------------

## 4.4 Wishlist / planned places

The product may eventually support another state for places the user
wants to visit.

The concept is:

-   Visited
-   Wishlist / Want to visit

However, the exact presentation and interaction model should remain
flexible.

The wishlist should complement the travel map rather than turn the
product into a planning application.

The user's travel history remains the primary focus.

------------------------------------------------------------------------

# 5. Country Experience

Selecting a country from the map should open a dedicated country
overview.

The country page is the first major information layer after the world
map.

It should combine:

1.  The user's relationship with the country.
2.  The user's memories and content.
3.  Travel statistics.
4.  Country information.
5.  Relevant cities.

------------------------------------------------------------------------

## 5.1 Country overview

A country page should visually establish the selected country.

Potential elements include:

-   country name
-   flag
-   country imagery
-   geographic information
-   user's visit status
-   number of cities visited
-   number of visits, if tracked
-   approximate number of days spent there, if tracked
-   number of photographs
-   other relevant personal statistics

The exact statistics should be refined later based on which information
provides genuine value.

The page should not become a generic Wikipedia page.

The user's experience should remain the focus.

------------------------------------------------------------------------

# 6. Country Memories

A country should aggregate the user's memories associated with that
country.

The user may have visited multiple cities within the same country.

The country page should therefore act as a higher-level collection of
their experiences.

For example:

## Portugal

The page could contain:

-   country overview
-   personal statistics
-   cities visited
-   country-level gallery
-   memories
-   country facts
-   relevant information

The user should be able to see the country as a whole before deciding to
explore a specific city.

------------------------------------------------------------------------

# 7. Country Gallery

The country page may contain photographs associated with the country.

Initially, the gallery does **not need to separate photographs into
trips**.

The first version should simply allow the user to have a collection of
photographs associated with the location.

Photographs can later become more structured.

A future version may introduce additional gallery organization,
including separation by individual trips or visits.

However:

> **The initial gallery should remain simple.**

The product should not force users to organize their photographs into
complicated structures.

------------------------------------------------------------------------

# 8. Country Statistics

Country pages should contain personal statistics about the user's
relationship with that country.

Examples:

-   Number of cities visited
-   Number of visits
-   Number of days spent
-   Number of photos
-   First visit
-   Most recent visit
-   Favourite city, if the user chooses to define one
-   Number of memories

Additional statistics can be introduced if they are genuinely
interesting.

The principle is:

> Statistics should describe the user's relationship with the country,
> not simply reproduce generic country facts.

------------------------------------------------------------------------

# 9. Country Facts and Information

The country page can also contain general information about the country.

Potential categories:

-   capital
-   population
-   language(s)
-   currency
-   continent
-   region
-   interesting facts
-   geographic information
-   cultural information
-   other useful country details

These facts should enrich the experience but should not overpower the
user's personal content.

The distinction should remain clear between:

### About the country

Generic factual information.

### Your experience

The user's personal travel history.

------------------------------------------------------------------------

# 10. City Experience

A city is the next level of exploration.

The intended hierarchy is:

**World → Country → City**

A country should expose the cities that the user has associated with
that country.

Selecting a city opens a dedicated city page.

The city page should feel more personal and detailed than the country
page.

------------------------------------------------------------------------

# 11. City Page

The city page should combine:

-   city identity
-   user statistics
-   personal memories
-   photographs
-   facts
-   general information
-   optional personal notes
-   a mini travel-journal feeling

The city page should feel like:

> **"My history with this city."**

rather than:

> **"A generic information page about this city."**

------------------------------------------------------------------------

# 12. City Mini Travel Journal

The city page should include a lightweight travel-journal concept.

This does not mean introducing a full journal application.

The goal is simply to allow the user to add context around their
experiences.

Potential content:

-   short notes
-   personal descriptions
-   favourite moments
-   observations
-   recommendations to themselves
-   memories associated with the city
-   captions or descriptions for photographs

The user should be able to make the page personal without being forced
to write long-form content.

A city with many photographs but no text should still feel complete.

A city with detailed notes should become more personal for users who
want that.

------------------------------------------------------------------------

# 13. City Gallery

The city should have a dedicated photograph gallery.

Initially, the gallery should be straightforward:

> **All photographs associated with this city.**

There does not need to be a mandatory trip structure.

The user should be able to upload or associate photographs with the city
and have them displayed together.

The system may later introduce more organization.

Possible future concepts include:

-   visits
-   trips
-   albums
-   dates
-   thematic collections

But those should remain future possibilities rather than part of the
initial conceptual requirement.

------------------------------------------------------------------------

# 14. City Statistics

Potential city statistics include:

-   number of visits
-   total days
-   number of photographs
-   number of memories
-   first visit
-   most recent visit
-   number of associated places
-   personal rating, if eventually introduced

Statistics should remain secondary to the actual memories.

------------------------------------------------------------------------

# 15. City Facts and Details

City pages can include useful information such as:

-   country
-   region
-   population
-   geographic information
-   notable landmarks
-   interesting facts
-   local characteristics
-   other useful contextual information

Again, this content should support the user's experience rather than
transform the application into a city encyclopedia.

------------------------------------------------------------------------

# 16. Cities Should Not Be Limited to "Important Cities"

A major design principle is:

> **The user decides what places matter to them.**

The application should not assume that only famous cities are worth
recording.

A user may have visited:

-   a major capital
-   a small town
-   an old village
-   a coastal town
-   a remote destination
-   a location that has personal significance

Therefore, the application should allow users to associate their travel
history with meaningful locations rather than relying entirely on a
predefined list of "important cities."

Generic city information can still exist for recognized locations, but
the user's personal travel history should not be constrained by
popularity.

------------------------------------------------------------------------

# 17. Places Beyond Cities

The concept should remain open to locations that are not technically
cities.

Examples:

-   towns
-   villages
-   islands
-   national parks
-   historical sites
-   other destinations

This is important because travel experiences are not naturally limited
to administrative city boundaries.

However, this should not overcomplicate the initial product.

The primary hierarchy remains:

**World → Country → City / Place**

The exact broader place model can evolve later.

------------------------------------------------------------------------

# 18. Personal Profile

Every user should have a travel profile.

The profile is a visual summary of their travel history.

It should provide an immediate answer to:

> **"Where has this person been?"**

The interactive map should remain an important part of the profile.

------------------------------------------------------------------------

# 19. Profile Statistics

The profile should contain a collection of interesting travel
statistics.

Core examples:

-   Countries visited
-   Cities visited
-   Continents visited
-   Number of memories
-   Number of photographs

Potential additional statistics:

-   Travel days
-   Most visited country
-   Most visited city
-   First country visited
-   Most recently visited country
-   Most photographed city
-   Country with the most cities visited
-   Number of places visited
-   Other meaningful derived statistics

Statistics should be visually attractive but understandable.

The goal is to make the profile interesting to explore, not to turn
travel into a competitive scoreboard.

------------------------------------------------------------------------

# 20. Continents

Continents should be represented in the profile statistics.

Example:

> **4 / 7 continents**

This provides a high-level sense of progression.

The number should be derived from the user's visited countries.

The product should avoid presenting this as a mandatory achievement.

It is simply an interesting representation of travel coverage.

------------------------------------------------------------------------

# 21. Travel Achievements and Badges

The product should support achievements defined by the product itself.

Achievements are optional visual recognition of milestones.

Examples could include:

-   First country visited
-   First continent
-   5 countries visited
-   10 countries visited
-   25 countries visited
-   First visit to another continent
-   Visit every country in a defined region
-   Visit all continents
-   Visit a certain number of cities
-   Other interesting travel milestones

When achieved, the user receives a badge on their profile.

The achievement system should be designed by the product rather than
allowing users to define arbitrary achievements.

------------------------------------------------------------------------

## 21.1 Achievement philosophy

Achievements should feel like:

> **"I unlocked something because of my travel history."**

They should not feel like aggressive gamification.

The product should not encourage users to travel purely to collect
badges.

Badges are a visual celebration of the user's existing experiences.

------------------------------------------------------------------------

# 22. Travel Progress

The map itself is the primary progress indicator.

As the user visits more places:

-   more countries become highlighted
-   more cities become available
-   more memories appear
-   statistics increase
-   achievements unlock

This means the user's progress is visible without requiring a dedicated
progress screen.

The world itself becomes the progress visualization.

------------------------------------------------------------------------

# 23. Shareable Profile

Each user should have a shareable profile.

A user should be able to share their profile with friends using a link.

The shared profile should allow another person to experience the user's
travel world.

Potentially visible information:

-   profile name
-   profile image
-   countries visited
-   continents
-   cities
-   map
-   statistics
-   selected public memories
-   selected photographs
-   achievements

The shared profile should preserve the visual identity of the
application.

It should not feel like a plain public database page.

------------------------------------------------------------------------

# 24. Privacy

Privacy is a fundamental product requirement.

Not everything a user stores should automatically be public.

Content should support different visibility levels.

Potential levels:

### Private

Only the user can see it.

### Friends

Only accepted friends/connections can see it.

### Public

Anyone viewing the user's profile can see it.

### Unlisted / Link-only

Content can be accessed through a direct link without necessarily being
publicly discoverable.

The exact privacy model can be refined later, but the principle is
clear:

> **The user owns their travel history and decides what they expose.**

------------------------------------------------------------------------

# 25. Attachments

Users should be able to associate additional files with their travel
memories.

Examples:

-   itinerary PDFs
-   travel documents
-   maps
-   tickets
-   reservations
-   other useful travel files

Attachments should be private by default.

The purpose is preservation and organization.

The application should not require these documents to be public simply
because the associated destination is public.

------------------------------------------------------------------------

# 26. Photo and Media Preservation

Photographs are one of the most important content types.

The product should treat them as memories rather than merely files.

Photos should be associated with places so that they naturally appear
in:

-   city galleries
-   country galleries
-   potentially profile highlights

The first version should favor simplicity.

Users should not have to perform extensive organization before seeing
value.

------------------------------------------------------------------------

# 27. Friends and Social Connections

The product should include a social component, but it should be
deliberately limited.

The goal is:

> **Explore your friends' travel worlds.**

Not:

> **Consume an endless social media feed.**

Users should be able to:

-   add friends
-   view friends' profiles
-   see their visited places, according to privacy settings
-   explore their countries and cities
-   compare travel coverage

------------------------------------------------------------------------

# 28. Travel Comparison

A particularly valuable social feature is comparing two users' travel
histories.

For example:

### Places you both visited

🇵🇹 Portugal\
🇪🇸 Spain\
🇮🇹 Italy

### Places your friend visited but you haven't

🇬🇷 Greece\
🇯🇵 Japan

### Places you visited but your friend hasn't

🇫🇷 France\
🇩🇪 Germany

This creates a social interaction directly related to the core product.

It also naturally encourages conversation:

> "You've been to Greece? I haven't."

or

> "We both went to Rome."

This is preferable to generic social interactions such as likes and
follower counts.

------------------------------------------------------------------------

# 29. No Instagram-Style Feed

The product should not initially include an algorithmic social feed.

There should be no need to constantly post updates.

No requirement for:

-   likes
-   follower counts
-   public engagement metrics
-   viral posts
-   endless scrolling
-   popularity rankings

A person's travel profile should be valuable even if nobody else
interacts with it.

The product is an archive first and a social experience second.

------------------------------------------------------------------------

# 30. Shared Travel Experiences Without a Trip Model

Multiple people may have travelled to the same destination together.

The product does not need a formal shared-trip entity initially.

Instead, the social relationship can exist at the place level.

For example:

Two friends can both have:

**Italy → Rome**

and see that they shared the same destination.

A more advanced collaborative travel concept can be considered later if
the product demonstrates a need for it.

It should not be part of the initial core model.

------------------------------------------------------------------------

# 31. Wishlist / Future Places

Users should eventually be able to mark places they want to visit.

This introduces a distinction between:

-   places experienced
-   places desired

The wishlist should remain subordinate to the travel archive.

It should not transform the application into a full travel planner.

Potentially, wishlist places can appear differently on the world map.

The exact visual and interaction model is intentionally open.

------------------------------------------------------------------------

# 32. Personal Travel Identity

Over time, the profile should become more than a country count.

It should communicate a person's travel identity through:

-   countries
-   cities
-   photographs
-   memories
-   statistics
-   achievements
-   map coverage

The profile should feel unique to the individual.

Two people may both have visited 20 countries, but their maps and
memories can look completely different.

The application should emphasize this uniqueness.

------------------------------------------------------------------------

# 33. Interesting Derived Statistics

The system can calculate statistics from existing data.

Potential examples:

### Geography

-   Countries visited
-   Continents visited
-   Cities visited
-   Countries per continent

### Time

-   Total travel days
-   First recorded travel
-   Most recent travel
-   Longest relationship with a country

### Places

-   Most visited country
-   Most visited city
-   Most photographed city
-   Country with the most cities visited

### Content

-   Total photographs
-   Memories created
-   Public memories
-   Private memories

The list should grow only when a statistic is genuinely interesting.

Avoid creating statistics purely because the data exists.

------------------------------------------------------------------------

# 34. Facts vs Personal Data

The application should clearly distinguish between:

## Global information

Facts about:

-   countries
-   cities
-   geography
-   culture
-   notable places

and:

## Personal information

Data about:

-   user's visits
-   user's photographs
-   user's memories
-   user's statistics
-   user's preferences
-   user's achievements

The user should never feel that the application is merely showing them
information that could be found anywhere.

The value comes from combining **the world with the user's personal
history**.

------------------------------------------------------------------------

# 35. Visual Identity

The application should be:

-   modern
-   visual
-   immersive
-   clean
-   elegant
-   map-centric
-   visually rewarding

The world map should be one of the strongest visual elements in the
entire product.

The visual style should support exploration.

The user should feel encouraged to:

> zoom → discover → click → explore

rather than:

> open menu → select list → read database

------------------------------------------------------------------------

# 36. Globe vs Flat Map

The product can support either:

-   a 3D interactive globe
-   a flat world map

The preferred experience is an interactive globe/map that makes the
world itself the navigation mechanism.

The exact implementation is not part of this document.

The conceptual requirement is:

> **The world should be directly explorable and interactive.**

------------------------------------------------------------------------

# 37. Navigation Philosophy

The product should minimize unnecessary navigation layers.

A natural flow should be possible:

**World**

↓

**Country**

↓

**City**

↓

**Memories / Gallery / Details**

The user should always understand where they are geographically.

For example, while exploring a city, the interface should still make it
obvious that the city belongs to a country and that the country belongs
to the world.

------------------------------------------------------------------------

# 38. Returning to the Map

The world map should remain the central navigation anchor.

The user should be able to return to the world and continue exploring.

This reinforces the idea that:

> The entire application is a representation of one world belonging to
> one user.

------------------------------------------------------------------------

# 39. Data Organization Philosophy

The product should organize content around **places**, not around files.

The user should not think:

> "Where did I upload this photograph?"

They should think:

> "This photograph belongs to Lisbon."

The application should then make that content accessible from the
relevant context.

Similarly:

> Country → all relevant cities and country memories

> City → all relevant photographs and city memories

This location-centric organization is one of the fundamental principles
of the product.

------------------------------------------------------------------------

# 40. The Relationship Between Country and City

A country is not simply a folder containing cities.

The country page should have its own identity.

It should contain:

-   country-level statistics
-   country-level facts
-   country-level memories
-   country-level photographs
-   the user's overall relationship with the country

Cities then provide a deeper level of detail.

Example:

**Italy**

> 4 cities visited\
> 12 days\
> 400 photos

↓

**Rome**

> 5 days\
> 180 photos

↓

**Florence**

> 3 days\
> 120 photos

↓

**Venice**

> 4 days\
> 100 photos

This hierarchy gives users both overview and depth.

------------------------------------------------------------------------

# 41. Multiple Visits

A user may visit the same country or city multiple times.

The application should support this naturally.

The user should not have to create duplicate country or city entities.

Instead:

> **Portugal**

can contain the user's complete relationship with Portugal across all
visits.

Similarly:

> **Lisbon**

can contain the user's complete history with Lisbon.

This is one of the reasons not to make individual trips the primary
organizational model.

------------------------------------------------------------------------

# 42. Country and City Memories Across Time

Because memories are associated with locations rather than trips, a city
can gradually become a personal archive.

For example:

**Lisbon**

2019 memories\
2022 memories\
2024 memories\
2026 memories

Initially these can simply appear together.

More advanced temporal organization can be introduced later if needed.

------------------------------------------------------------------------

# 43. Future Gallery Organization

The initial product should not require detailed organization of photos.

However, the gallery architecture should conceptually leave room for
future organization.

Possible future dimensions:

-   visit
-   date
-   trip
-   album
-   event
-   location within the city

This is a future enhancement, not a core requirement.

The initial goal is simply:

> **Get the user's travel memories into the right place.**

------------------------------------------------------------------------

# 44. User-Generated Content

The user's content is the heart of the product.

Users should be able to contribute:

-   photographs
-   short memories
-   notes
-   optional ratings or favourites
-   attachments
-   other personal travel information

The application should not dictate how much content a user has to
create.

A user who only wants a map should be able to use the product.

A user who wants a detailed personal archive should be able to build
one.

------------------------------------------------------------------------

# 45. Profile Quality Should Grow Naturally

A new profile may contain:

> 3 countries\
> 7 cities\
> 120 photos

An older profile may contain:

> 32 countries\
> 94 cities\
> 14,000 photos\
> 80 memories\
> 12 achievements

The product should become more valuable as the user's travel history
grows.

This creates a long-term relationship with the application without
requiring artificial engagement mechanics.

------------------------------------------------------------------------

# 46. Core User Journey

## First experience

A new user enters the application.

They are presented with the world.

They can begin marking or importing places they have visited.

As countries are added:

-   the map changes
-   their profile statistics update
-   cities become available
-   their travel world starts taking shape

------------------------------------------------------------------------

## Exploring a country

The user clicks a visited country.

They see:

-   country identity
-   their personal statistics
-   country information
-   memories
-   photographs
-   cities they have visited

They can select a city.

------------------------------------------------------------------------

## Exploring a city

The user enters the city page.

They see:

-   city information
-   personal statistics
-   photographs
-   memories
-   mini travel-journal content
-   relevant details

They can return to the country or world.

------------------------------------------------------------------------

## Sharing

The user shares their profile.

A friend opens it.

The friend can explore:

-   the user's map
-   countries
-   cities
-   public memories
-   public photographs
-   statistics
-   achievements

If they are also a user, the two profiles can eventually be compared.

------------------------------------------------------------------------

# 47. The Product's Core Loop

The fundamental loop is:

**Travel somewhere**

↓

**Add the place**

↓

**Map changes**

↓

**Add memories/photos**

↓

**Profile becomes richer**

↓

**Statistics and achievements update**

↓

**Share/explore with friends**

↓

**Travel somewhere new**

↓

**Return to the map**

The loop is intentionally simple.

There does not need to be a constant content-consumption loop.

The user's real-world travel provides the primary source of new content.

------------------------------------------------------------------------

# 48. What Makes the Product Valuable

The product combines several things that are usually separated:

### A visual travel map

Where have I been?

### A personal archive

What did I experience?

### A photo collection

What did it look like?

### A knowledge layer

What is this place?

### A statistics layer

How much of the world have I experienced?

### A social layer

Where have my friends been?

### A progression layer

What have I achieved?

The combination is the product.

No individual feature needs to carry the entire experience.

------------------------------------------------------------------------

# 49. Core Product Principles

The following principles should guide future decisions.

## Principle 1 --- Map first

The world map is the primary entry point and primary visual identity.

## Principle 2 --- Places over trips

Countries and cities are the fundamental organizational structure.

Individual trips should not be a first-class concept initially.

## Principle 3 --- Personal history over generic information

Facts about countries and cities enrich the experience, but the user's
travel history is the reason the product exists.

## Principle 4 --- Archive over social media

The product should preserve experiences rather than maximize engagement.

## Principle 5 --- Social without becoming Instagram

Friends, sharing and comparison are valuable, but there should be no
feed-centric social model.

## Principle 6 --- User-controlled privacy

Travel information and memories should be private by default where
appropriate.

## Principle 7 --- Simple first

Users should receive value without having to perform extensive
organization.

## Principle 8 --- Grow with the user

The application should become more meaningful as the user travels more.

## Principle 9 --- Every place can matter

The product should not define a hierarchy where only famous cities are
considered meaningful.

## Principle 10 --- Progress should be visual

The world map itself should communicate the user's growth as a
traveller.

------------------------------------------------------------------------

# 50. Explicitly Out of Scope for the Initial Concept

The following ideas have been considered but are intentionally not part
of the initial product definition:

-   Trip as a first-class entity
-   Timeline as a primary navigation feature
-   Instagram-style social feed
-   Likes and engagement metrics
-   Full collaborative trip system
-   Full travel planning platform
-   Travel booking
-   Flight tracking
-   AI travel recommendations
-   Monetization strategy
-   Premium subscription model
-   Complex itinerary management
-   Dedicated long-form memory/journal system
-   Automatic separation of galleries by trip
-   Detailed region-by-region travel tracking
-   Competitive leaderboards

These may be reconsidered in the future, but they should not influence
the initial definition of the product.

------------------------------------------------------------------------

# 51. Future Possibilities

The following concepts may become valuable later without being required
for the initial product:

-   Trip-based organization
-   Gallery separation by visit/trip
-   More advanced wishlist functionality
-   Collaborative travel experiences
-   More detailed place types
-   Automatic photo organization
-   Advanced travel statistics
-   Additional achievement systems
-   Richer friend comparison
-   Personalized travel insights
-   Travel books / physical memory products
-   Additional profile customization

The existence of these possibilities should not force them into the
initial product.

The core product should remain understandable without them.

------------------------------------------------------------------------

# 52. The Full Concept in One Sentence

> **A map-centric personal travel archive where your world becomes a
> visual record of the countries and cities you've experienced, enriched
> with your photographs, memories, statistics and achievements, and
> optionally shared and compared with friends.**

------------------------------------------------------------------------

# 53. The Full Concept in One Paragraph

The product is an interactive travel archive centered around a
personalized world map. Users see the world as the main entry point,
with countries they have visited visually highlighted. They can zoom,
explore and select a country to discover their personal statistics,
photographs, memories, facts and the cities they have experienced there.
Selecting a city opens a deeper personal page containing its own
memories, gallery, statistics, facts and lightweight travel-journal
content. Over time, the user's map becomes a visual representation of
their travel history, while their profile summarizes their countries,
cities, continents, achievements and other meaningful statistics. Users
can share their profiles and connect with friends, allowing them to
explore each other's travel worlds and compare places they have both or
individually experienced. The product is intentionally designed as a
personal archive and visual travel identity rather than an
Instagram-style social network, travel planner or booking platform.
