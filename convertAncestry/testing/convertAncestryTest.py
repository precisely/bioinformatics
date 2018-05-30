from mamba import description, context, it
from expects import expect, equal
import convertAncestry
import datetime

with description('Testing Ancestry.com -> 23andme converter'):
    with('The header is being written')
        converted_filename = 'converted_' + datetime.now() + '.txt'
        handle_metadata('tester.txt', converted_filename)

        num_lines = 0
        with open(converted_filename, 'r') as f:
            for line in f:
            num_lines += 1

        assertEquals(num_lines, 3)

    with('Data being copied')        
        