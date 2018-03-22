#!/usr/bin/python

import os, sys, unittest, convert23andme

class Test_parse_23andMe_file(unittest.TestCase):

    def test_parse(self):
        self.assertTrue(convert23andme.parse_23andMe_file('shorttest_deadbeef.txt'))


class Test_convert_23andme_bcf(unittest.TestCase):

    def test_conversion(self):
        self.assertTrue(convert23andme.convert_23andme_bcf('convert23andme/shorttest_deadbeef.txt',
                                                              'data/human_g1k_v37.fasta.gz',
                                                              'convert23andme/ucsc-gene-symbols-coords.txt.gz',
                                                              '/tmp'))



if __name__ == '__main__':
    unittest.main()
