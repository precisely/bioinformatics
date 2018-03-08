from setuptools import setup

## System (apt) install:
## *samtools, bcftools, tabix

setup(
    name='convert23andme',
    version='0.1',
    description='Convert 23&Me tab-delimited files to VCF and GA4GH format.',
    author='Tomer Altman',
    author_email='analytics@tomeraltman.net',
    packages=['convert23andme'],
    install_requires=['pysam'])
