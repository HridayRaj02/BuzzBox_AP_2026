# Normalization

For this example, I have treated BuzzBox as a campus feed where students can post, react, comment, and add tags. The repository did not include the app schema, so I used these features as the basis for the tables below.

## Before normalization

If all the feed data went into one table, a post with several reactions, comments, and tags would be awkward to store. We would either put lists in some columns or repeat the post and author details across a lot of rows. The rough shape might look like this:

```text
Feed(PostID, PostBody, PostedAt,
     AuthorID, AuthorName, AuthorEmail, ProgramID, ProgramName,
     Reactions[(MemberID, MemberName, Reaction)],
     Comments[(CommentID, MemberID, CommentBody, CommentedAt)],
     Tags[TagName])
```

The lists in this example are repeating groups. There is also a practical problem with repeating the author details: if a student changes their name or program, every copy would have to be updated.

## First normal form (1NF)

In 1NF, each cell holds a single value. I would put reactions, comments, and tags in rows rather than keeping lists inside a post row. If I flattened everything into one table, the post details would repeat. Combining tags and reactions in that table would also produce extra rows, since each tag would be paired with each reaction even though they are separate things.

At this stage, the values are atomic, but the repeated post, author, and program details still need to be sorted out.

## Second normal form (2NF)

The flattened table has a composite key. For example, a reaction is identified by both `PostID` and the reacting `MemberID`. But `PostBody`, `PostedAt`, and `AuthorID` depend on `PostID` alone. That means some columns depend on only part of the key, so the table is not in 2NF yet.

I split the data into separate tables based on what each set of details belongs to:

```text
Posts(PostID, PostBody, PostedAt, AuthorID, AuthorName, AuthorEmail,
      ProgramID, ProgramName)
PostReactions(PostID, MemberID, Reaction)
Comments(CommentID, PostID, MemberID, CommentBody, CommentedAt)
PostTags(PostID, TagName)
```

In `PostReactions`, both `PostID` and `MemberID` are needed to identify a reaction. The pair `(PostID, TagName)` identifies a tag on a post. Each comment has its own `CommentID`. With the post details moved into `Posts`, they now depend on the whole key of that table.

## Third normal form (3NF)

There is one more dependency to remove. In `Posts`, the `PostID` tells us the `AuthorID`, and the `AuthorID` tells us the member's name, email, and program. The `ProgramID` also determines the `ProgramName`. Keeping all of that in `Posts` would duplicate member and program details across posts.

I moved those details into `Members` and `Programs`. The final tables are:

```text
Programs(
    ProgramID (Primary Key),
    ProgramName
)

Members(
    MemberID (Primary Key),
    DisplayName,
    Email UNIQUE,
    ProgramID (Foreign Key) -> Programs.ProgramID
)

Posts(
    PostID (Primary Key),
    AuthorID (Foreign Key) -> Members.MemberID,
    PostBody,
    PostedAt
)

PostReactions(
    PostID (Foreign Key) -> Posts.PostID,
    MemberID (Foreign Key) -> Members.MemberID,
    Reaction,
    Primary Key (PostID, MemberID)
)

Comments(
    CommentID (Primary Key),
    PostID (Foreign Key) -> Posts.PostID,
    MemberID (Foreign Key) -> Members.MemberID,
    CommentBody,
    CommentedAt
)

Tags(
    TagID (Primary Key),
    TagName UNIQUE
)

PostTags(
    PostID (Foreign Key) -> Posts.PostID,
    TagID (Foreign Key) -> Tags.TagID,
    Primary Key (PostID, TagID)
)
```

Now the post, member, and program details are each stored once. `PostReactions` and `PostTags` connect records without copying the related details into every row. This also makes simple changes safer: updating a member's email or renaming a tag does not mean editing old posts.
