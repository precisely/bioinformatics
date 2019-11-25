#!/usr/bin/perl

my $timestamp =  1000000 + int(rand(9999 - 1000));

my ($fileName, $Refpop) = @ARGV;

#number of individuals
$fileFam=$fileName.".fam";
$count = `wc -l < $fileFam`;
my ($first_num) = $count =~ /(\d+)/;
`./plink --bfile Data/$Refpop  --write-snplist`;

open($fileH,$fileFam);
@listOfIndivs;
while($line=<$fileH>){
    print $line."\n";
    push(@listOfIndivs,$line);

}
close($fileH);
unlink("thisIter.txt");
unlink("uniq.list");
unlink("header.list");

foreach (@listOfIndivs) {

    @newAry=split(" ",$_);
    $strName=$newAry[0]."_".$newAry[1]."_".$timestamp;
    

    open($fileH2,">","$strName.keep") or die("keep not created");
    print $fileH2 $_;

    `./plink --bfile $fileName --keep $strName.keep --extract plink.snplist --make-bed --out $strName`;
    `./plink --bfile $fileName --keep $strName.keep --extract plink.snplist --make-bed --out ThisIsATest`;

    $strName2= $strName."Test";
    $strName2Miss=$strName2."-merge.missnp";
    if(-e "$strName2Miss") 
    {
        unlink("$strName2Miss");
    }
    `./plink --bfile Data/$Refpop --bmerge $strName.bed $strName.bim $strName.fam --make-bed --out $strName2`;
    if (-e "$strName2Miss") 
    { 
        system("mv $strName2Miss flip");
        $flip1 = "./plink --bfile $strName --flip  flip --make-bed --out $strName";
        system($flip1);
        `./plink --bfile Data/$Refpop --bmerge $strName.bed $strName.bim $strName.fam --make-bed --out $strName2`;
        #file exists - set variable and other things
    }

    if (-e "$strName2Miss")
    { 
        $exclude = "./plink --bfile $strName --exclude  $strName2Miss --make-bed --out $strName ";
        system($exclude);
        `./plink --bfile Data/$Refpop --bmerge $strName.bed $strName.bim $strName.fam --make-bed --out $strName2`;
        #file exists - set variable and other things
    }

    #unlink("$strName2Miss");
    #unlink("flip");	

    `./plink --bfile $strName2 --make-bed --out $strName`;

    `sed '/AA_Ref/! s/^.*-9/_/g'  $strName.fam > $strName.pop.txt `;
    `cut -d' '  -f1 $strName.pop.txt > $strName.pop `;
    `sed -i.bak 's/AA_Ref_//g'  $strName.pop `;
    `uniq  $strName.pop | grep '[a-zA-Z]' > $timestamp.uniq.list`;

    $count = `wc -l < $timestamp.uniq.list`;
    ($K) = $count =~ /(\d+)/;

    `tr -s '\n'  ' '< $timestamp.uniq.list > $timestamp.header.list `;
    `sed -i.bak '1s/^/Group ID /'  $timestamp.header.list `;
    `./admixture -j8 -s time --supervised $strName.bed $K `;
    print "./admixture -j8 -s time --supervised $strName.bed $K ";
    `cut -d' ' -f1,2 $strName.fam > $timestamp.colLabels.txt`;

    `paste -d ' ' $timestamp.colLabels.txt $strName.$K.Q | grep -v "AA_Ref" >> $timestamp.thisIter.txt`;
    `cat $timestamp.thisIter.txt >> $timestamp.header.list `;
    $outName=$fileName."_".$Refpop.".".$timestamp.".csv";
    `cp $timestamp.header.list $outName`;

    # remove keep
    unlink($strName.".keep");
    unlink($strName.".bed");
    unlink($strName.".fam");
    unlink($strName.".bim");
    unlink($strName.".log");
    unlink($strName.".nosex");
    unlink($strName.".pop");
    unlink($strName.".pop.bak");
    unlink($strName.".pop.txt");

    unlink($strName.".".$K.".Q");
    unlink($strName.".".$K.".P");

    close($fileH2);

}

unlink($timestamp.".thisIter.txt");
unlink($timestamp.".header.list");
unlink($timestamp.".header.list.bak");
unlink($timestamp.".colLabels.list");
unlink($timestamp.".colLabels.txt");
unlink($timestamp.".uniq.list");
