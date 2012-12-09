#!/usr/bin/env ruby

keylist = ["PLAINSEQ","ENCSEQ","INTSEQ"]

def getchar_call(key,posexpr)
  if key == "PLAINSEQ"
    return "(unsigned long)\nsainseq->seq.plainseq[#{posexpr}]"
  elsif key == "INTSEQ"
    return "sainseq->seq.array[#{posexpr}]"
  else
    return "ISSPECIAL(tmpcc = gt_encseq_get_encoded_char(\n" +
                                  "sainseq->seq.encseq,\n" +
                                  "#{posexpr},\n" +
                                  "sainseq->readmode))\n" +
               "  ? GT_UNIQUEINT(#{posexpr}) : (unsigned long) tmpcc"
  end
end

def declare_tmpcc(key,context)
  if key == "ENCSEQ"
    return "GtUchar tmpcc;\n#{context};"
  else
    return "#{context};"
  end
end

begin
  fo = File.open("src/match/sfx-sain.inc","w")
rescue => err
  STDERR.puts "#{$0}: #{err}"
  exit 1
end

keylist.each do |key|
fo.puts <<CCODE
static unsigned long gt_sain_#{key}_insertSstarsuffixes(GtSainseq *sainseq,
                                                 unsigned long *suftab)
{
  unsigned long position,
                nextcc = GT_UNIQUEINT(sainseq->totallength),
                countSstartype = 0,
                *fillptr = sainseq->bucketfillptr;
  GtSainbuffer *sainbuffer = gt_sainbuffer_new(suftab,fillptr,
                                               sainseq->numofchars);
  #{declare_tmpcc(key,"bool nextisStype = true")}

  gt_sain_endbuckets(sainseq);
  for (position = sainseq->totallength-1; /* Nothing */; position--)
  {
    unsigned long currentcc = #{getchar_call(key,"position")};
    bool currentisStype = (currentcc < nextcc ||
                           (currentcc == nextcc && nextisStype)) ? true : false;
    if (!currentisStype && nextisStype)
    {
      countSstartype++;
      if (sainseq->sstarfirstcharcount != NULL)
      {
        sainseq->sstarfirstcharcount[nextcc]++;
      }
      if (sainbuffer != NULL)
      {
        gt_sainbuffer_update(sainbuffer,nextcc,position);
      } else
      {
        suftab[--fillptr[nextcc]] = position;
      }
#undef SAINSHOWSTATE
#ifdef SAINSHOWSTATE
      printf("Sstar.suftab[%lu]=%lu\\n",fillptr[nextcc],position+1);
#endif
    }
    nextisStype = currentisStype;
    nextcc = currentcc;
    if (position == 0)
    {
      break;
    }
  }
  gt_sainbuffer_flushall(sainbuffer);
  gt_sainbuffer_delete(sainbuffer);
  gt_assert(GT_MULT2(countSstartype) <= sainseq->totallength);
  return countSstartype;
}

static void gt_sain_#{key}_induceLtypesuffixes1(GtSainseq *sainseq,
                                         long *suftab,
                                         unsigned long nonspecialentries)
{
  unsigned long lastupdatecc = 0, *fillptr;
  long *bucketptr = NULL;
  #{declare_tmpcc(key,"long *suftabptr")}

  fillptr = sainseq->bucketfillptr;
  for (suftabptr = suftab, sainseq->currentround = 0;
       suftabptr < suftab + nonspecialentries; suftabptr++)
  {
    long position = *suftabptr;

    if (position > 0)
    {
      unsigned long currentcc;

      if (position >= (long) sainseq->totallength)
      {
        gt_assert(sainseq->roundtable != NULL);
        sainseq->currentround++;
        position -= (long) sainseq->totallength;
      }
      currentcc = #{getchar_call(key,"(unsigned long) position")};
      if (currentcc < sainseq->numofchars)
      {
        if (position > 0)
        {
          unsigned long leftcontextcc;

          gt_assert(position > 0);
          position--;
          leftcontextcc = #{getchar_call(key,"(unsigned long) position")};
          if (sainseq->roundtable != NULL)
          {
            unsigned long t = (currentcc << 1) |
                              (leftcontextcc < currentcc ? 1UL : 0);

            gt_assert(currentcc > 0 &&
                      sainseq->roundtable[t] <= sainseq->currentround);
            if (sainseq->roundtable[t] < sainseq->currentround)
            {
              position += (long) sainseq->totallength;
              sainseq->roundtable[t] = sainseq->currentround;
            }
          }
          GT_SAINUPDATEBUCKETPTR(currentcc);
          /* negative => position does not derive L-suffix
             positive => position may derive L-suffix */
          gt_assert(suftabptr < bucketptr);
          *bucketptr++ = (leftcontextcc < currentcc) ? ~position : position;
          *suftabptr = 0;
#ifdef SAINSHOWSTATE
          gt_assert(bucketptr != NULL);
          printf("L-induce: suftab[%lu]=%ld\\n",
                  (unsigned long) (bucketptr-1-suftab),*(bucketptr-1));
#endif
        }
      } else
      {
        *suftabptr = 0;
      }
    } else
    {
      if (position < 0)
      {
        *suftabptr = ~position;
      }
    }
  }
}

static void gt_sain_#{key}_induceStypesuffixes1(GtSainseq *sainseq,
                                         long *suftab,
                                         unsigned long nonspecialentries)
{
  unsigned long lastupdatecc = 0, *fillptr = sainseq->bucketfillptr;
  long *bucketptr = NULL;
  #{declare_tmpcc(key,"long *suftabptr")}

  gt_sain_special_singleSinduction1(sainseq,
                                    suftab,
                                    (long) (sainseq->totallength-1));
  if (sainseq->seqtype == GT_SAIN_ENCSEQ)
  {
    gt_sain_induceStypes1fromspecialranges(sainseq,
                                           sainseq->seq.encseq,
                                           suftab);
  }
  if (nonspecialentries == 0)
  {
    return;
  }
  for (suftabptr = suftab + nonspecialentries - 1; suftabptr >= suftab;
       suftabptr--)
  {
    long position = *suftabptr;

    if (position > 0)
    {
      if (position >= (long) sainseq->totallength)
      {
        gt_assert(sainseq->roundtable != NULL);
        sainseq->currentround++;
        position -= (long) sainseq->totallength;
      }
      if (position > 0)
      {
        unsigned long currentcc
          = #{getchar_call(key,"(unsigned long) position")};

        if (currentcc < sainseq->numofchars)
        {
          unsigned long leftcontextcc;

          position--;
          leftcontextcc
            = #{getchar_call(key,"(unsigned long) position")};
          if (sainseq->roundtable != NULL)
          {
            unsigned long t = (currentcc << 1) |
                              (leftcontextcc > currentcc ? 1UL : 0);

            gt_assert(sainseq->roundtable[t] <= sainseq->currentround);
            if (sainseq->roundtable[t] < sainseq->currentround)
            {
              position += sainseq->totallength;
              sainseq->roundtable[t] = sainseq->currentround;
            }
          }
          GT_SAINUPDATEBUCKETPTR(currentcc);
          gt_assert(bucketptr != NULL && bucketptr - 1 < suftabptr);
          *(--bucketptr) = (leftcontextcc > currentcc)
                            ? ~(position+1) : position;
#ifdef SAINSHOWSTATE
          printf("S-induce: suftab[%lu]=%ld\\n",
                  (unsigned long) (bucketptr - suftab),*bucketptr);
#endif
        }
      }
      *suftabptr = 0;
    }
  }
}

static void gt_sain_#{key}_induceLtypesuffixes2(const GtSainseq *sainseq,
                                         long *suftab,
                                         unsigned long nonspecialentries)
{
  unsigned long lastupdatecc = 0, *fillptr = sainseq->bucketfillptr;
  long *bucketptr = NULL;
  #{declare_tmpcc(key,"long *suftabptr")}

  for (suftabptr = suftab; suftabptr < suftab + nonspecialentries; suftabptr++)
  {
    long position = *suftabptr;

    *suftabptr = ~position;
    if (position > 0)
    {
      unsigned long currentcc;

      position--;
      currentcc = #{getchar_call(key,"(unsigned long) position")};
      if (currentcc < sainseq->numofchars)
      {
        gt_assert(currentcc > 0);
        GT_SAINUPDATEBUCKETPTR(currentcc);
        gt_assert(bucketptr != NULL && suftabptr < bucketptr);
        *bucketptr++ = (position > 0 &&
                        (#{getchar_call(key,"(unsigned long) (position-1)")})
                                            < currentcc)
                        ? ~position : position;
#ifdef SAINSHOWSTATE
        gt_assert(bucketptr != NULL);
        printf("L-induce: suftab[%lu]=%ld\\n",
               (unsigned long) (bucketptr-1-suftab),*(bucketptr-1));
#endif
      }
    }
  }
}

static void gt_sain_#{key}_induceStypesuffixes2(const GtSainseq *sainseq,
                                         long *suftab,
                                         unsigned long nonspecialentries)
{
  unsigned long lastupdatecc = 0, *fillptr = sainseq->bucketfillptr;
  long *bucketptr = NULL;
  #{declare_tmpcc(key,"long *suftabptr")}

  gt_sain_special_singleSinduction2(sainseq,
                                    suftab,
                                    (long) sainseq->totallength,
                                    nonspecialentries);
  if (sainseq->seqtype == GT_SAIN_ENCSEQ)
  {
    gt_sain_induceStypes2fromspecialranges(sainseq,
                                           sainseq->seq.encseq,
                                           suftab,
                                           nonspecialentries);
  }
  if (nonspecialentries == 0)
  {
    return;
  }
  for (suftabptr = suftab + nonspecialentries - 1; suftabptr >= suftab;
       suftabptr--)
  {
    long position = *suftabptr;

    if (position > 0)
    {
      unsigned long currentcc;

      position--;
      currentcc = #{getchar_call(key,"(unsigned long) position")};
      if (currentcc < sainseq->numofchars)
      {
        GT_SAINUPDATEBUCKETPTR(currentcc);
        gt_assert(bucketptr != NULL && bucketptr - 1 < suftabptr);
        *(--bucketptr) = (position == 0 ||
                          (#{getchar_call(key,"(unsigned long) (position-1)")})
                                             > currentcc)
                         ? ~position : position;
#ifdef SAINSHOWSTATE
        gt_assert(bucketptr != NULL);
        printf("S-induce: suftab[%lu]=%ld\\n",
                (unsigned long) (bucketptr-suftab),*bucketptr);
#endif
      }
    } else
    {
      *suftabptr = ~position;
    }
  }
}

static void gt_sain_#{key}_expandorder2original(GtSainseq *sainseq,
                                         unsigned long numberofsuffixes,
                                         unsigned long *suftab)
{
  unsigned long *suftabptr, position,
                writeidx = numberofsuffixes - 1,
                nextcc = GT_UNIQUEINT(sainseq->totallength),
                *sstarsuffixes = suftab + numberofsuffixes;
  unsigned long *sstarfirstcharcount = NULL, *bucketsize = NULL;
  #{declare_tmpcc(key,"bool nextisStype = true")}

  if (sainseq->seqtype == GT_SAIN_INTSEQ)
  {
    unsigned long charidx;

    gt_assert(sainseq->sstarfirstcharcount == NULL);
    sstarfirstcharcount = sainseq->sstarfirstcharcount
                        = sainseq->bucketfillptr;
    bucketsize = sainseq->bucketsize;
    for (charidx = 0; charidx < sainseq->numofchars; charidx++)
    {
      sstarfirstcharcount[charidx] = 0;
      bucketsize[charidx] = 0;
    }
  }
  for (position = sainseq->totallength-1; /* Nothing */; position--)
  {
    unsigned long currentcc = #{getchar_call(key,"position")};
    bool currentisStype = (currentcc < nextcc ||
                           (currentcc == nextcc && nextisStype)) ? true : false;

    if (!currentisStype && nextisStype)
    {
      if (sstarfirstcharcount != NULL)
      {
        sstarfirstcharcount[nextcc]++;
      }
      sstarsuffixes[writeidx--] = position+1;
    }
    if (bucketsize != NULL)
    {
      bucketsize[currentcc]++;
    }
    nextisStype = currentisStype;
    nextcc = currentcc;
    if (position == 0)
    {
      break;
    }
  }
  for (suftabptr = suftab; suftabptr < suftab + numberofsuffixes; suftabptr++)
  {
    *suftabptr = sstarsuffixes[*suftabptr];
  }
}
CCODE
end