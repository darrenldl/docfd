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

def main():
    args = parser.parse_args()

    if args.command == 'init':
        fake = Faker('en_US')

        os.makedirs('bob-files', exist_ok=True)

        for y in range(2010, 2010 + 1):
            for m in range(1, 12 + 1):
                for _ in range(0, random.randint(10,20)):
                    d = random.randint(1,28)
                    date_str = f"{y:04}-{m:02}-{d:02}"
                    print(date_str)

        print(fake.word())
    elif args.command == 'start':
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
""")

# For file name, type key `f` to enter FILTER mode, and type `path-fuzzy:hint` (Tab to autocomplete to save typing).
# 


        questionary.press_any_key_to_continue().ask()

        subprocess.run(["docfd", "bob-files"])

if __name__ == "__main__":
    main()
