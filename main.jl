@enum Suit spades hearts diamonds clubs
@enum Color black red

suit_colors = Dict(spades => black, hearts => red, diamonds => red, clubs => black)
suit_representations = Dict(spades => Char(0x2660), hearts => Char(0x2661), diamonds => Char(0x2662), clubs => Char(0x2663))

color(suit::Suit) = suit_colors[suit]

Base.string(suit::Suit) = string(suit_representations[suit])

rankmin = 1
rankmax = 13

struct Rank
    value::Int

    function Rank(value::Int)
        if value < rankmin || value > rankmax
            error("value must be >= $(rankmin) and <= $(rankmax)")
        end
        new(value)
    end
end

function Base.show(io::IO, rank::Rank)
    value = rank.value
    if value == 1
        print(io, " A")
    elseif value == 10
        print(io, 10)
    elseif value == 11
        print(io, " J")
    elseif value == 12
        print(io, " Q")
    elseif value == 13
        print(io, " K")
    else
        print(io, ' ', value)
    end
end

Base.instances(Rank) = map(Rank, rankmin:rankmax)

is_successor_of(rank::Rank, other::Rank) = (rank.value == other.value + 1)

struct Card
    rank::Rank
    suit::Suit
    Card(rank::Int, suit::Suit) = new(Rank(rank), suit)
    Card(rank::Rank, suit::Suit) = new(rank, suit)
end

color(card::Card) = color(card.suit)

Base.show(io::IO, card::Card) = print(io, string(card.rank), string(card.suit))

struct Deck
    cards::Vector{Card}

    function Deck()
        cards::Vector{Card} = []
        for suit in instances(Suit)
            for rank in instances(Rank)
                push!(cards, Card(rank, suit))
            end
        end
        Deck(cards)
    end

    function Deck(cards::Vector{Card})
        new(cards)
    end
end

Base.length(deck::Deck) = length(deck.cards)
Base.rand(deck::Deck) = rank(deck.cards)

Base.isempty(deck::Deck) = isempty(deck.cards)

function shuffle(deck::Deck)
    dict = Dict{Int, Card}()
    cards = deck.cards
    shuffled = Vector{Card}()
    foreach(k -> dict[k] = cards[k], keys(cards))
    for i in 0:(length(cards) - 1)
        k = dict |> keys |> rand
        push!(shuffled, dict[k])
        delete!(dict, k)
    end
    Deck(shuffled)
end

function deal!(deck::Deck, num::Int)
    dealt::Vector{Card} = []
    while (length(dealt) != num) && !isempty(deck.cards)
        push!(dealt, pop!(deck.cards))
    end
    return dealt
end
function dealone!(deck::Deck)
    pop!(deck.cards)
end

# Foundations

mutable struct FoundationPosition
    suit::Suit
    rank::Union{Rank, Nothing}
    FoundationPosition(suit::Suit) = new(suit, nothing)
end

can_give(position::FoundationPosition) = false

function can_receive(position::FoundationPosition, card::Card)
    if card.suit != position.suit
        return false
    end
    if isnothing(position.rank)
        return card.rank.value == 1
    end
    return is_successor(card.rank, position.rank)
end

function receive!(position::FoundationPosition, card::Card)
    position.rank = card.rank
end

iscomplete(foundation::FoundationPosition) = (!isnothing(foundation.rank) && (foundation.rank.value == 13))

function Base.show(io::IO, foundation::FoundationPosition)
    if isnothing(foundation.rank)
        print(io, "  ", string(foundation.suit))
    else
        print(io, string(foundation.rank), string(foundation.suit))
    end
end

# Columns

mutable struct ColumnPosition
    cards::Vector{Card}
end

function next_card(columnPosition::ColumnPosition)
    if isempty(columnPosition.cards)
        return nothing
    end
    return last(columnPosition.cards)
end

can_give(position::ColumnPosition) = !isempty(position.cards)

function can_receive(position::ColumnPosition, card::Card)
    top = next_card(position)
    isnothing(top) || (color(top) != color(card) && is_successor_of(top.rank, card.rank))
end

function give!(position::ColumnPosition)
    if isempty(position.cards)
        return nothing
    end
    pop!(position.cards)
end

receive!(position::ColumnPosition, card::Card) = push!(position.cards, card)

# Hand

mutable struct HandPosition
    card::Union{Card, Nothing}
end

can_give(position::HandPosition) = !isnothing(position.card)

can_receive(position::HandPosition, card::Card) = false

function give!(position::HandPosition)
    card = position.card
    position.card = nothing
    card
end

function Base.show(io::IO, position::HandPosition)
    if isnothing(position.card)
        print(io, "   ")
    else
        print(io, string(position.card))
    end
end

next_card(position::HandPosition) = position.card

mutable struct Game
    foundations::Vector{FoundationPosition}
    columns::Vector{ColumnPosition}
    hand::Vector{HandPosition}

    function Game(shuffleddeck::Deck)
        foundations = map(s -> FoundationPosition(s), [spades, hearts, diamonds, clubs])

        columns::Vector{ColumnPosition} = []
        for i in 1:9
            cards = deal!(shuffleddeck, i)
            column = ColumnPosition(cards)
            push!(columns, column)
        end

        hand::Vector{HandPosition} = []
        while !isempty(shuffleddeck)
            card = dealone!(shuffleddeck)
            handposition = HandPosition(card)
            push!(hand, handposition)
        end

        new(foundations, columns, hand)
    end
end

function Base.show(io::IO, game::Game)
    # print foundations
    println(io, "\033[2J\033[H") # clear screen
    foundationsstr = map(string, game.foundations) |> fs -> join(fs, ' ')
    println(io, "                      a   b   c   d")
    println(io, "------------------------------------")
    println(io, "                    ", foundationsstr)
    println(io, "")

    # print columns
    println(io, "  e   f   g   h   i   j   k   l   m")
    println(io, "------------------------------------")
    i = 1
    while true
        exhaustedcolumns = true
        for column in game.columns
            if i > length(column.cards)
                print(io, "    ")
            else
                print(io, string(column.cards[i]), ' ')
                exhaustedcolumns = false
            end
        end
        if exhaustedcolumns
            break
        end
        println(io, "")
        i += 1
    end
    println(io, "")

    # print hand
    println(io, "  n   o   p   q   r   s   t")
    println(io, "------------------------------------")
    for handposition in game.hand
        print(io, string(handposition), ' ')
    end
    println(io, "")
end

function get_position(game::Game, label::Char)
    if label == 'a'
        game.foundations[1]
    elseif label == 'b'
        game.foundations[2]
    elseif label == 'c'
        game.foundations[3]
    elseif label == 'd'
        game.foundations[4]

    elseif label == 'e'
        game.columns[1]
    elseif label == 'f'
        game.columns[2]
    elseif label == 'g'
        game.columns[3]
    elseif label == 'h'
        game.columns[4]
    elseif label == 'i'
        game.columns[5]
    elseif label == 'j'
        game.columns[6]
    elseif label == 'k'
        game.columns[7]
    elseif label == 'l'
        game.columns[8]
    elseif label == 'm'
        game.columns[9]

    elseif label == 'n'
        game.hand[1]
    elseif label == 'o'
        game.hand[2]
    elseif label == 'p'
        game.hand[3]
    elseif label == 'q'
        game.hand[4]
    elseif label == 'r'
        game.hand[5]
    elseif label == 's'
        game.hand[6]
    elseif label == 't'
        game.hand[7]
    else
        nothing
    end
end

function iswin(game::Game)
    foundations = game.foundations
    iscomplete(foundations[1]) && iscomplete(foundations[2]) && iscomplete(foundations[3]) && iscomplete(foundations[4])
end

function play(game::Game)
    show(game)
    while !iswin(game)
        println()
        print("Enter move: ")
        input = readline()
        if input == "quit" || input == "exit"
            exit()
        end
        if length(input) != 2
            println("Invalid input; please enter two characters.")
        end
        first_char = input[1]
        second_char = input[2]
        from = get_position(game, first_char)
        to = get_position(game, second_char)
        if isnothing(from)
            println("Invalid FROM character")
            continue
        end
        if isnothing(to)
            println("Invalid TO character")
            continue
        end
        if !can_give(from)
            println("You cannot play a card from there.")
            continue
        end
        if !can_receive(to, next_card(from))
            println("You cannot move that card there.")
            continue
        end
        receive!(to, give!(from))
        show(game)
    end

    println("Well done, you won!")
end

function main()
    Deck() |> shuffle |> Game |> play
end

main()
