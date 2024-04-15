import re

def validate_credit_card(card_number):
    pattern = r"^(?!.*(\d)(-?\1){3})[4-6]\d{3}-?\d{4}-?\d{4}-?\d{4}$"
    return bool(re.match(pattern, card_number))

# Test cases
card_numbers = [
    "A123-4567-8901-2345",
    "B111-2222-3333-4444",
    "C999-8888-7777-6666",
    "4567-1234-5678-9012",
]

for card_number in card_numbers:
    if validate_credit_card(card_number):
        print(f"{card_number} is valid.")
    else:
        print(f"{card_number} is invalid.")
