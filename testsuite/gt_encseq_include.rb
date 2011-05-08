Name "gt encseq encode|decode simple"
Keywords "gt_encseq_encode encseq gt_encseq_decode"
Test do
  run "#{$bin}gt encseq encode #{$testdata}foobar.fas"
  run "#{$bin}gt encseq decode foobar.fas"
  run "diff #{$last_stdout} #{$testdata}foobar.fas"
end

Name "gt encseq encode multiple files without indexname"
Keywords "encseq gt_encseq_encode"
Test do
  run "#{$bin}gt encseq encode #{$testdata}foobar.fas"
  run_test "#{$bin}gt encseq encode #{$testdata}foobar.fas " + \
           "#{$testdata}foobar.fas", :retval => 1
  grep($last_stderr, /if more than one input file is given/)
end

Name "gt encseq decode lossless without ois"
Keywords "encseq gt_encseq_decode lossless"
Test do
  run "#{$bin}gt encseq encode #{$testdata}foobar.fas"
  run_test "#{$bin}gt encseq decode -lossless foobar.fas", \
           :retval => 1
  grep($last_stderr, /cannot open file.*ois/)
end

STDREADMODES  = ["fwd", "rev"]
DNAREADMODES  = STDREADMODES + ["cpl", "rcl"]
DNATESTSEQS   = ["#{$testdata}foobar.fas",
                 "#{$testdata}gt_bioseq_succ_3.fas",
                 "#{$testdata}at100K1"]
AATESTSEQS    = ["#{$testdata}trembl-eqlen.faa"]
NUMSAMPLES    = 5

def revcomp(seq)
  comp(seq).reverse
end

def comp(seq)
  seq.tr("aAcCgGtTnNrRyYmMkKwWsSbBdDhHvV","tTgGcCaAnNyYrRkKmMwWsSvVhHdDbB")
end

def mapwildcards(seq)
  seq.downcase.tr("rRyYmMkKwWsSbBdDhHvV", "nNnNnNnNnNnNnNnNnNnN")
end

def getseq(filename, mirrored = false, rm = "fwd")
  sequences = []
  rcseqs = []
  File.open(filename) do |file|
    seqs = file.read.split(">")
    seqs.shift
    seqs.each do |seq|
      seqarr = seq.split(/\n/)
      header = seqarr.shift.chomp
      seq = seqarr.collect{|v| v.chomp}.join('')
      sequences.push(seq)
      rcseqs.push(revcomp(seq))
    end
  end
  ret =  sequences.join("|")
  if mirrored then
    ret += "|" + rcseqs.reverse.join("|")
  end
  case rm
    when "fwd" then
      #pass
    when "rev" then
      ret = ret.reverse
    when "cpl" then
      ret = comp(ret)
    when "rcl" then
      ret = revcomp(ret)
    else
      raise "unknown readmode"
  end
  ret
end

def run_encseq_comparison(filename, mirrored, lossless, readmode, singlechars,
                          numsamples = NUMSAMPLES)
  seq = getseq(filename, mirrored, readmode)
  ranges = []
  numsamples.times do
    len = rand((seq.length)/2)
    start = rand(seq.length-1-len);
    stop = start + len
    ranges.push([start, stop])
  end

  ranges.each do |rng|
    line = "#{$bin}gt encseq decode -output concat " + \
           "-range #{rng[0]} #{rng[1]} " + \
           "#{"-lossless" if lossless} " + \
           "-dir #{readmode} #{"-mirrored" if mirrored} " + \
           "#{"-singlechars" if singlechars} #{filename.split('/').last}"
    if mirrored and AATESTSEQS.include?(filename)
      # -mirroring should fail on proteins
      run_test(line, :retval => 1)
    else
      run_test line
      File.open("seqout", "w+") do |f|
        outseq = seq[rng[0]..rng[1]]
        if DNATESTSEQS.include?(filename) and !lossless then
          outseq = mapwildcards(outseq)
        end
        f.write(outseq)
        f.write("\n")
      end
      run "diff seqout #{$last_stdout}"
    end
  end
end

def testformirrored(s, readmode)
  Name "gt encseq decode #{s.split('/').last} #{readmode}"
  Keywords "encseq gt_encseq_decode mirroring lossless"
  Test do
    [false, true].each do |lossless|
      run "#{$bin}gt encseq encode -des -ssp -sds " + \
              "#{"-lossless" if lossless} " + \
              "#{s}"
      [false, true].each do |mirrored|
        [false, true].each do |singlechars|
          run_encseq_comparison(s, mirrored, lossless, readmode, singlechars)
          seq = getseq(s, mirrored, readmode)
          line = "#{$bin}gt encseq decode -output concat -dir #{readmode} " + \
                  "#{"-mirrored" if mirrored} " + \
                  "#{"-lossless" if lossless} " + \
                  "#{"-singlechars" if singlechars} ./#{s.split('/').last}"
          if mirrored and AATESTSEQS.include?(s)
            # -mirroring should fail on proteins
            run_test(line, :retval => 1)
          else
            run_test line
            File.open("seqout", "w+") do |f|
              if DNATESTSEQS.include?(s) and !lossless then
                seq = mapwildcards(seq)
              end
              f.write(seq)
              f.write("\n")
            end
            run "diff seqout #{$last_stdout}"
          end
        end
      end
    end
  end
end

DNATESTSEQS.each do |s|
  DNAREADMODES.each do |readmode|
    testformirrored(s, readmode)
  end
end

AATESTSEQS.each do |s|
  STDREADMODES.each do |readmode|
    testformirrored(s, readmode)
  end
end


fastafiles = ["Atinsert.fna",
              "Duplicate.fna",
              "Random-Small.fna",
              "Random.fna",
              "Copysorttest.fna",
              "Random159.fna",
              "Random160.fna",
              "RandomN.fna",
              "TTT-small.fna",
              "trna_glutamine.fna",
              "Small.fna",
              "Verysmall.fna",
              "Arabidopsis-C99826.fna"]
genbankfiles = fastafiles.collect{ |f| f.gsub(".fna",".gbk") }
emblfiles = fastafiles.collect{ |f| f.gsub(".fna",".embl") }

[genbankfiles, emblfiles].each do |formatfiles|
  formatfiles.each do |formatfile|
    Name "gt sequence formats (#{formatfile})"
    Keywords "gt_encseq formats"
    Test do
      fasta = formatfile.gsub(/\.[a-z]+$/, ".fna")
      if File.exists?("#{$testdata}#{fasta}") then
        run "cp #{$testdata}#{formatfile} infile"
        run_test "#{$bin}gt encseq encode -v -indexname sfx infile"
        run_test "#{$bin}gt encseq decode -output concat sfx > sfx.seq"
        run_test "#{$bin}gt encseq info sfx > sfx.info"
        run_test "#{$bin}gt encseq check sfx"
        run "cp #{$testdata}#{fasta} infile"
        run_test "#{$bin}gt encseq encode -v -indexname sfx infile"
        run_test "#{$bin}gt encseq decode -output concat sfx > sfx2.seq"
        run_test "#{$bin}gt encseq info sfx > sfx2.info"
        run "diff sfx.seq sfx2.seq"
        run "diff sfx.info sfx2.info"
      end
    end
  end
end

Name "gt encseq mirrored trailing wildcard"
Keywords "encseq gt_encseq_encode wildcards mirror"
Test do
  run "cp #{$testdata}wildcardatend.fna infile"
  run_test "#{$bin}gt encseq encode infile"
  run_test "#{$bin}gt encseq info -mirrored infile | grep range > mirr.info"
  run "cp #{$testdata}wildcardatend_rev.fna infile"
  run_test "#{$bin}gt encseq encode infile"
  run_test "#{$bin}gt encseq info infile | grep range > rev.info"
  run "diff mirr.info rev.info"
end

Name "gt encseq mirrored no trailing wildcard"
Keywords "encseq gt_encseq_encode wildcards mirror"
Test do
  run "cp #{$testdata}nowildcardatend.fna infile"
  run_test "#{$bin}gt encseq encode infile"
  run_test "#{$bin}gt encseq info -mirrored infile | grep range > mirr.info"
  run "cp #{$testdata}nowildcardatend_rev.fna infile"
  run_test "#{$bin}gt encseq encode infile"
  run_test "#{$bin}gt encseq info infile | grep range > rev.info"
  run "diff mirr.info rev.info"
end

Name "gt encseq decode single sequence"
Keywords "encseq gt_encseq_decode single"
Test do
  run "#{$bin}gt encseq encode -indexname foo #{$testdata}Atinsert.fna"
  run_test "#{$bin}gt encseq decode -seq 3 foo"
  run "diff #{$last_stdout} #{$testdata}Atinsert_single_3.fna"
end

Name "gt encseq decode single sequence (reverse)"
Keywords "encseq gt_encseq_decode single"
Test do
  run "#{$bin}gt encseq encode -indexname foo #{$testdata}Atinsert.fna"
  run_test "#{$bin}gt encseq decode -dir rev -seq 17 foo"
  run "diff #{$last_stdout} #{$testdata}Atinsert_single_3_rev.fna"
end

Name "gt encseq decode single sequence (invalid seqnumber)"
Keywords "encseq gt_encseq_decode single"
Test do
  run "#{$bin}gt encseq encode -indexname foo #{$testdata}Atinsert.fna"
  run_test "#{$bin}gt encseq decode -seq 36 foo", :retval => 1
  grep $last_stderr, /exceeds/
end

Name "gt encseq decode single sequence (with -output concat)"
Keywords "encseq gt_encseq_decode single"
Test do
  run "#{$bin}gt encseq encode -indexname foo #{$testdata}Atinsert.fna"
  run_test "#{$bin}gt encseq decode -output concat -seq 36 foo", :retval => 1
  grep $last_stderr, /can only be used with the/
end

Name "gt encseq decode sequence range"
Keywords "encseq gt_encseq_decode seqrange"
Test do
  run "#{$bin}gt encseq encode -indexname foo #{$testdata}Atinsert.fna"
  run_test "#{$bin}gt encseq decode -seqrange 3 7 foo"
  run "diff #{$last_stdout} #{$testdata}Atinsert_seqrange_3-7.fna"
end

Name "gt encseq decode sequence range (reverse)"
Keywords "encseq gt_encseq_decode seqrange"
Test do
  run "#{$bin}gt encseq encode -indexname foo #{$testdata}Atinsert.fna"
  run_test "#{$bin}gt encseq decode -dir rev -seqrange 13 17 foo"
  run "diff #{$last_stdout} #{$testdata}Atinsert_seqrange_13-17_rev.fna"
end

Name "gt encseq decode sequence range (invalid range start)"
Keywords "encseq gt_encseq_decode seqrange"
Test do
  run "#{$bin}gt encseq encode -indexname foo #{$testdata}Atinsert.fna"
  run_test "#{$bin}gt encseq decode -seqrange 37 49 foo", :retval => 1
  grep $last_stderr, /exceeding/
end

Name "gt encseq decode sequence range (invalid range end)"
Keywords "encseq gt_encseq_decode seqrange"
Test do
  run "#{$bin}gt encseq encode -indexname foo #{$testdata}Atinsert.fna"
  run_test "#{$bin}gt encseq decode -seqrange 3 49 foo", :retval => 1
  grep $last_stderr, /exceeding/
end

Name "gt encseq decode sequence range (with -output concat)"
Keywords "encseq gt_encseq_decode seqrange"
Test do
  run "#{$bin}gt encseq encode -indexname foo #{$testdata}Atinsert.fna"
  run_test "#{$bin}gt encseq decode -output concat -seqrange 3 49 foo", \
           :retval => 1
  grep $last_stderr, /can only be used with the/
end

Name "gt encseq Lua bindings"
Keywords "encseq gt_scripts "
Test do
  run_test "#{$bin}gt #{$testdata}gtscripts/encseq.lua #{$testdata}"
end
