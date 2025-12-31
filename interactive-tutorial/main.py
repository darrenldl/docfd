import argparse
import os
import random
import questionary
import subprocess
from faker import Faker

parser = argparse.ArgumentParser(prog='interactive-tutorial')
subparsers = parser.add_subparsers(dest='command')

parser_init = subparsers.add_parser('init')

parser_start = subparsers.add_parser('start')

BOB_FILES = 'bob-files'

DATA_DIR = '/tmp/docfd-interactive-tutorial/data'

CACHE_DIR = '/tmp/docfd-interactive-tutorial/cache'

def run_docfd(dir, script=None):
    args = ["docfd",
            "--cache-dir",
            CACHE_DIR,
            "--data-dir",
            DATA_DIR,
            dir]
    capture_output = False
    if script is not None:
        args.append("--script")
        args.append(script)
        capture_output = True
    return subprocess.run(args, capture_output=capture_output)

def main():
    args = parser.parse_args()

    if args.command == 'init':
        fake = Faker('en_US')

        os.makedirs(BOB_FILES, exist_ok=True)

        for y in range(2010, 2010 + 1):
            for m in range(1, 12 + 1):
                for _ in range(0, random.randint(10,20)):
                    d = random.randint(1,28)
                    date_str = f"{y:04}-{m:02}-{d:02}"
                    print(date_str)

        with open(os.path.join(BOB_FILES, 'note_2010-12-31.txt'), 'w') as f:
            f.write("""Writing down some hints for future reference as we are storing the the archive of the
year into cold storage at midnight.
Password is: my favourite food + my favourite drink.

Check receipts used for reimbursement for what I spent the most on.
""")
    elif args.command == 'start':
        os.makedirs(CACHE_DIR, exist_ok=True)
        os.makedirs(DATA_DIR, exist_ok=True)

        print(f"""Welcome to the Docfd interactive tutorial. There will be an interactive puzzle to demonstrate the main uses of Docfd, with some additional challenges for advanced users.
""")

        questionary.press_any_key_to_continue().ask()

        user_name = questionary.text("What do you want to be called in this tutorial?").ask()
        print(f"""
Hello {user_name}, you arrived just in time!

We are trying to find an old contact signed way back in 2010 October,
but we don't have it on our cloud drive.
We suspect it has been archived into our cold storage along with the other documents, but we don't have the password to unlock the encrypted archive.
""")

        questionary.press_any_key_to_continue().ask()

        print(f"""
Bob, our IT guy, told us that you would be able to help us while he is off to holiday.
He said you are free to dig through his files from 2010, it should have some enough hints for what the archive password is during that time.

Docfd has been set up for you to start digging through Bob's files.
""")

        questionary.press_any_key_to_continue().ask()

        print(f"""
Bob mentioned he wrote down the "password hint" somewhere, lets start off with that.

To search for a phrase in Docfd, first type `/` to enter SEARCH mode, then enter: password hint

When you are finished, use Ctrl+C to exit Docfd to return to the puzzle dialog.

(Don't worry about remembering the file name right now, next step will be about saving your solution for the puzzle program to read.)
""")

# For file name, type key `f` to enter FILTER mode, and type `path-fuzzy:hint` (Tab to autocomplete to save typing).
# 

        questionary.press_any_key_to_continue().ask()

        run_docfd(BOB_FILES)

        print(f"""
Seems like you have given Docfd a short try.

Now let's do the same search again and pass the file with the hint to the
puzzle program.

This will require the use of the scripting functionality of Docfd,
which allows you to save and load Docfd sessions (similar to the
the "save query" or "save view" functionality of other document search programs).

After you have completed the search and pinpointed the file with the password hint, drop unrelated files by typing `dD` (if there are more than one file), and use Ctrl+S to save the session as a Docfd script.

In practice, you would pick a name you'd remember for the script. But for the purpose of this tutorial, input "solution" so the final name is "solution.docfd-script".
""")

        questionary.press_any_key_to_continue().ask()

        run = True
        while run:
            run_docfd("bob-files")

            res = run_docfd("bob-files", script=f"{DATA_DIR}/scripts/solution.docfd-script")
            print(res)
            break
        
if __name__ == "__main__":
    main()
