use src::logic::utils::{StackTrait, Felt252Stack, NullableStack};


fn char_count(str: felt252) -> u32 {
    let u_str: u256 = str.try_into().unwrap();
    let mut r = u_str;
    let mut char_count: u32 = 1;
    while (r > 255) {
        r = r / 255;
        char_count += 1;
    };
    return char_count;
}

fn array_to_dict(array: @Array<u8>) -> Felt252Dict<u8> {
    let mut new_dict: Felt252Dict<u8> = Default::default();
    let array_len = array.len();
    let mut index: u32 = 0;

    while (index < array_len) {
        match array.get(index) {
            Option::Some(x) => { new_dict.insert(index.into(), *x.unbox()); },
            Option::None => {}
        }
        index += 1;
    };
    return new_dict;
}

fn dict_to_array(ref dict: Felt252Dict<u8>) -> Array<u8> {
    let mut new_array: Array<u8> = Default::default();
    let mut index: u32 = 0;
    let mut isEnd = false;
    while (isEnd == false) {
        let new_value = dict.get(index.into());
        new_array.append(new_value);
        index += 1;
    };
    return new_array;
}

fn check_instr(
    instr: u8, cmd_sequence: @ByteArray, ref loop_starts: Felt252Stack<u32>, ref cmd_index: u32
) {
    if instr == 62 { // >
    } else if instr == 60 { // <
    } else if instr == 43 { //+
    } else if instr == 45 { //-
    } else if instr == 91 { // [
        let mut nest_level = 1; //enter loop current loop
        while nest_level != 0 { //look for imbricated loop in the current loop
            cmd_index += 1; //skip next command while inside current loop
            let mut cmd = cmd_sequence.at(cmd_index);
            match cmd {
                Option::Some(instr) => {
                    if instr == 91 { // [
                        nest_level += 1; //new nested loop
                    }
                    if instr == 93 { // ]
                        nest_level -= 1; //end of nested loop
                    }
                },
                Option::None => panic!("No corresponding bracket"),
            };
        };
    } else if instr == 93 { // ]
        let mut jump_back_loop = loop_starts.pop(); //cmd_index gets value from index of loop start
        match jump_back_loop {
            Option::Some(jump_back_loop) => cmd_index = jump_back_loop - 1, //-1 or it skips cmd
            Option::None => panic!("No back loop"),
        };
    } else if instr == 46 { //.
    } else if instr == 44 { //,
    } else {
        panic!("Wrong command");
    }
}


fn apply_instr(
    instr: u8,
    ref cell_pointer: u32,
    ref cells: Felt252Dict<u8>,
    input_snap: @Array<u8>,
    cmd_sequence: @ByteArray,
    ref loop_starts: Felt252Stack<u32>,
    ref cmd_index: u32,
    ref input_index: u32
) {
    if instr == 62 { // >
        if cell_pointer == 255 {
            //overflow
            cell_pointer = 0;
        } else {
            cell_pointer += 1;
        }
    } else if instr == 60 { // <
        if cell_pointer == 0 {
            //underflow
            cell_pointer = 255;
        } else {
            cell_pointer -= 1;
        }
    } else if instr == 43 { //+
        let cell_value = cells.get(cell_pointer.into());
        if cell_value < 255 {
            cells.insert(cell_pointer.into(), cell_value + 1);
        } else {
            //overflow
            cells.insert(cell_pointer.into(), 0);
        }
    } else if instr == 45 { //-
        let cell_value = cells.get(cell_pointer.into());
        if cell_value > 0 {
            cells.insert(cell_pointer.into(), cell_value - 1);
        } else {
            cells.insert(cell_pointer.into(), 255);
        }
    } else if instr == 91 { // [
        let cell_value = cells.get(cell_pointer.into());
        if cell_value == 0 {
            let mut nest_level = 1; //enter loop current loop
            while nest_level != 0 { //look for imbricated loop in the current loop
                cmd_index += 1; //skip next command while inside current loop
                let mut cmd = cmd_sequence.at(cmd_index);
                match cmd {
                    Option::Some(instr) => {
                        if instr == 91 { // [
                            nest_level += 1; //new nested loop
                        }
                        if instr == 93 { // ]
                            nest_level -= 1; //end of nested loop
                        }
                    },
                    Option::None => println!("End"),
                };
            };
        } else {
            //record start of loop that will be executed
            loop_starts.push(cmd_index);
        }
    } else if instr == 93 { // ]
        let cell_value = cells.get(cell_pointer.into());
        let mut jump_back_loop = loop_starts.pop(); //cmd_index gets value from index of loop start
        if cell_value != 0 {
            match jump_back_loop {
                Option::Some(jump_back_loop) => cmd_index = jump_back_loop - 1, //-1 or it skips cmd
                Option::None => println!("Nothing to unwrap"),
            };
        }
    } else if instr == 46 { //.
        let cell_value = cells.get(cell_pointer.into());
        let mut printed_cell: ByteArray = "";
        printed_cell.append_byte(cell_value);
        println!("{printed_cell}"); // print character at current cell
    } else if instr == 44 { //,
        let input_value = input_snap.at(input_index);
        cells.insert(cell_pointer.into(), *input_value);
        println!("input {input_value}");
        input_index += 1;
    }
}

trait ProgramTrait {
    fn check(self: @Array<felt252>);
    fn execute(self: @Array<felt252>, input: Array<u8>) -> Array<u8>;
}

impl ProgramImpl of ProgramTrait {
    fn check(self: @Array<felt252>) {
        let mut loop_starts = StackTrait::<Felt252Stack, u32>::new(); //loop stack

        let mut program_index = 0;
        let mut cmd_sequence: ByteArray = "";
        let program = self;
        let program_length = program.len();

        //convert felt252 array into single ByteArray to iterate individual char using .at() (not possible with felt)
        while program_index < program_length {
            let mut cmd_sequence_felt = *program.at(program_index);
            let mut len_cmd_seq_felt = char_count(cmd_sequence_felt);

            cmd_sequence.append_word(cmd_sequence_felt, len_cmd_seq_felt);
            program_index += 1;
        };
        println!("Program : {cmd_sequence}");

        let cmd_sequence_length = cmd_sequence.len();
        let mut cmd_index: u32 = 0;

        while cmd_index < cmd_sequence_length {
            //match individual character to instructions +, -, >, <, etc.
            let mut cmd = cmd_sequence.at(cmd_index);
            match cmd {
                Option::Some(instr) => {
                    check_instr(instr, @cmd_sequence, ref loop_starts, ref cmd_index)
                },
                Option::None => println!("End Of Sequence"),
            };
            cmd_index += 1;
        };
    }

    fn execute(self: @Array<felt252>, input: Array<u8>) -> Array<u8> {
        let mut cell_pointer: u32 = 0;
        let input_snap = @input;
        let mut cells: Felt252Dict<u8> = array_to_dict(input_snap);
        let mut loop_starts = StackTrait::<Felt252Stack, u32>::new(); //loop stack
        let mut input_index = 0;

        let mut program_index = 0;
        let mut cmd_sequence: ByteArray = "";
        let program = self;
        let program_length = program.len();

        //convert felt252 array into single ByteArray to iterate individual char using .at() (not possible with felt)
        while program_index < program_length {
            let mut cmd_sequence_felt = *program.at(program_index);
            let mut len_cmd_seq_felt = char_count(cmd_sequence_felt);

            cmd_sequence.append_word(cmd_sequence_felt, len_cmd_seq_felt);
            program_index += 1;
        };
        println!("Program : {cmd_sequence}");

        let cmd_sequence_length = cmd_sequence.len();
        let mut cmd_index: u32 = 0;

        while cmd_index < cmd_sequence_length {
            //match individual character to instructions +, -, >, <, etc.
            let mut cmd = cmd_sequence.at(cmd_index);
            match cmd {
                Option::Some(instr) => {
                    apply_instr(
                        instr,
                        ref cell_pointer,
                        ref cells,
                        input_snap,
                        @cmd_sequence,
                        ref loop_starts,
                        ref cmd_index,
                        ref input_index
                    )
                },
                Option::None => println!("End Of Sequence"),
            };
            cmd_index += 1;
        };

        let returned_cells: Array<u8> = dict_to_array(ref cells);
        return returned_cells;
    }
}
