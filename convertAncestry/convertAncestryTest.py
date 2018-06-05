from mamba import description, context, it
import convertAncestry as conv
import datetime
import types
import expects
import os.path
import random

with description('Testing Ancestry.com -> 23andme converter:') as testConverter:
    with it('Creating input/output Generator and checking output file exists'):
        random_outfile_name = 'testing/test_outputs/out_23andMe.txt'
        in_generator = conv.input_file_generator('testing/AncestryDNA.txt')
        out_generator = conv.output_file_generator(random_outfile_name)
        #prime the generator
        out_generator.send(None)
        out_generator.send('TEST\n')
        with context('Input generator built'):
            assert type(in_generator) == types.GeneratorType
        with context('Output generator built'):
            assert type(out_generator) == types.GeneratorType
            assert os.path.isfile(random_outfile_name)
        with context('Outfile generator testing: output_file_generator().send()'):
            out_generator.send('This is a test\n')
            out_generator.send('12345\n')
            out_generator.send('Final line of test')
            try:
                out_generator.send('close')
            except(StopIteration):
                pass    
            expected = ['TEST\n', 'This is a test\n', '12345\n', 'Final line of test']
            with open(random_outfile_name, 'r') as out:
                for i in range(4):
                    testfile_line = out.readline()
                    assert expected[i] == testfile_line
    
    with it('Parsing correctly formatted AncestryDNA input header for metadata'):
        generator = conv.input_file_generator('testing/AncestryDNA.txt')
        genome_version, datetime_obj = conv.parse_metadata(generator)
        with context('Genome Version should be 37.1: parse_metadata()'):    
            assert genome_version == '37.1'
        with context('Datetime object should be the correct type: parse_metadata()'):
            assert type(datetime_obj) == datetime.datetime
   
    with it('Parsing incorrectly formatted timedate in AncestryDNA input header'):
        generator = conv.input_file_generator('testing/badtimeAncestryDNA.txt')  
        raised_exception = False
        msg = ''
        try:
            genome_version, datetime_obj = conv.parse_metadata(generator)
        except(ValueError) as v:
            raised_exception = True
            msg = str(v)
        with context('Testing bad date input/exception raising: parse_metadata()'):   
            assert raised_exception == True
            assert 'does not match format' in msg
        
    with it('Parsing incorrectly formatted human refrence genome in AncestryDNA input header'):
        generator = conv.input_file_generator('testing/badgenomeAncestryDNA.txt')  
        raised_exception = False
        msg = ''
        expects.expect(lambda: conv.parse_metadata(generator)).to(expects.raise_error(ValueError, 'Human Reference Genome number not found'))

    with it('Formatting proper input metadata'):
        expected = '# This data file generated by 23andMe on: Fri Apr 20 16:20:22 2018\n# More information on reference human assembly build 99\n#\trsid\tchromosome\tposition\tgenotype\n'       
        date_obj = datetime.datetime(2018, 4, 20, 16, 20, 22)
        result = conv.format_metadata(date_obj, 99)
        with context('Testing '):
            assert expected == result
    with it('Chromosome conversions test'):
        test = ['-1', '20', '21', '22', '23', '24', '25', '26', '27']
        result = []
        expected = [0, '20', '21', '22', 'X', 'Y', 'Y', 'MT', 0]
        for i in test:
            try:
                result.append(conv.convert_chromosome(i, 'rs140000'))
            except(ValueError):
                result.append(0)    

        for r in range(9):
            assert result[r] == expected[r]
    with it('Test formatting of actual data'):
        good_input = 'rs4475691\t5\t846808\tT\tC'
        expected_output_good_input = 'rs4475691\t5\t846808\tTC\n'
        skip_input = '#rsid4475691\t5\t846808\tT\tC'
        bad_input = 'This\tis\tnot\ta\tproper line'
        result = conv.format_data(good_input)
      
        assert result == expected_output_good_input
        assert conv.format_data(skip_input) == skip_input
        assert conv.format_data(bad_input) == None