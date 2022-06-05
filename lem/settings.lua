return {
    text_events={
        {
            name='testevent1',
            enabled=true,
            pattern='#*#say my name#*#'
        },
        {
            name='testevent2',
            enabled=true,
            pattern='#*#say my class#*#'
        }
    },
    condition_events={

    },
    characters={
        Character1={
            text_events={
                testevent1=1,
                testevent2=1,
            },
            condition_events={},
        },
    },
    settings={

    }
}
