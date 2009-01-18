/*
  Copyright (c) 2007 Stefan Kurtz <kurtz@zbh.uni-hamburg.de>
  Copyright (c) 2007 Center for Bioinformatics, University of Hamburg

  Permission to use, copy, modify, and distribute this software for any
  purpose with or without fee is hereby granted, provided that the above
  copyright notice and this permission notice appear in all copies.

  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
*/

#ifndef ENCSEQ_DEF_H
#define ENCSEQ_DEF_H

#include "core/chardef.h"
#include "core/str.h"
#include "core/str_array.h"
#include "core/symboldef.h"
#include "core/unused_api.h"
#include "core/filelengthvalues.h"
#include "seqpos-def.h"
#include "alphadef.h"
#include "intbits.h"
#include "readmode-def.h"
#include "verbose-def.h"

#define REVERSEPOS(TOTALLENGTH,POS) ((TOTALLENGTH) - 1 - (POS))
#define DBFILEKEY "dbfile="

#ifdef SKDEBUG
#define CHECKENCCHAR(CC,ENCSEQ,POS,READMODE)\
        {\
          Uchar cctmp = getencodedchar(ENCSEQ,POS,READMODE);\
          if ((CC) != cctmp)\
          {\
            printf("file %s, line %d: pos = %lu:cc = %u != %u = ccreal\n",\
                   __FILE__,__LINE__,\
                   (unsigned long) (POS),\
                   (unsigned int) (CC),\
                   (unsigned int) cctmp);\
            exit(EXIT_FAILURE);\
          }\
        }
#else
#define CHECKENCCHAR(CC,ENCSEQ,POS,READMODE)
#endif

typedef struct
{
  Seqpos leftpos,
         rightpos;
} Sequencerange;          /* \Typedef{Sequencerange} */

typedef struct
{
  Seqpos seqstartpos,  /* the position of the first character in the encseq */
         seqlength;    /* the length of the sequence */
} Seqinfo;             /* \Typedef{Seqinfo} */

#ifdef INLINEDENCSEQ

typedef struct
{
  Uchar *plainseq;
  Seqpos totallength;
  bool hasownmemory, mappedfile, hasspecialcharacters;
} Encodedsequence;

typedef struct
{
  bool moveforward, exhausted;
  const Encodedsequence *encseq;
  Seqpos pos,
         lengthofspecialrange;
} Specialrangeiterator;

typedef struct
{
  Readmode readmode;
} Encodedsequencescanstate;

#define getencseqtotallength(ENCSEQ) ((ENCSEQ)->totallength)

#define MAKECOMPL(CC)\
        (ISSPECIAL(CC) ? (CC) : (Uchar) 3 - (CC))

#define getencodedchar(ENCSEQ,POS,RM)\
        (((RM) == Forwardmode)\
          ? (ENCSEQ)->plainseq[POS]\
          : (((RM) == Reversemode)\
            ? (ENCSEQ)->plainseq[REVERSEPOS((ENCSEQ)->totallength,POS)]\
            : (((RM) == Complementmode) \
              ? MAKECOMPL((ENCSEQ)->plainseq[POS])\
              : (MAKECOMPL((ENCSEQ)->plainseq[\
                           REVERSEPOS((ENCSEQ)->totallength,POS)])\
              )\
            )\
          )\
        )

#define getencodedcharnospecial(ENCSEQ,POS,RM)\
        getencodedchar(ENCSEQ,POS,RM)

#define sequentialgetencodedchar(ENCSEQ,ENCSEQSTATE,POS,READMODE)\
        getencodedchar(ENCSEQ,POS,READMODE)

#else

typedef struct
{
  Twobitencoding tbe;           /* two bit encoding */
  unsigned int unitsnotspecial; /* units which are not special */
  Seqpos position;
} EndofTwobitencoding;

typedef struct Encodedsequence Encodedsequence;
typedef struct Encodedsequencescanstate Encodedsequencescanstate;
typedef struct Specialrangeiterator Specialrangeiterator;

Seqpos getencseqtotallength(const Encodedsequence *encseq);

unsigned long getencseqnumofdbsequences(const Encodedsequence *encseq);

Uchar getencodedchar(const Encodedsequence *encseq,Seqpos pos,
                     Readmode readmode);

Uchar getencodedcharnospecial(const Encodedsequence *encseq,
                              Seqpos pos,
                              Readmode readmode);

Uchar sequentialgetencodedchar(const Encodedsequence *encseq,
                               Encodedsequencescanstate *esr,
                               Seqpos pos,
                               Readmode readmode);

void extract2bitenc(bool fwd,
                    EndofTwobitencoding *ptbe,
                    const Encodedsequence *encseq,
                    Encodedsequencescanstate *esr,
                    Seqpos startpos);

int compareTwobitencodings(bool fwd,
                           bool complement,
                           unsigned int *commonunits,
                           const EndofTwobitencoding *ptbe1,
                           const EndofTwobitencoding *ptbe2);

uint64_t detsizeencseq(int kind,
                       Seqpos totallength,
                       Seqpos specialranges,
                       unsigned int mapsize);

void plainseq2bytecode(Uchar *bytecode,const Uchar *seq,unsigned long len);

void encseq2bytecode(Uchar *dest,const Encodedsequence *encseq,
                     const Seqpos startindex,const Seqpos len);

void sequence2bytecode(Uchar *dest,const Encodedsequence *encseq,
                       const Seqpos startindex,const Seqpos len);

#endif

/* the functions with exactly the same interface for both implementation of
   encodedsequences */

int flushencseqfile(const GtStr *indexname,Encodedsequence *encseq,GtError*);

Encodedsequencescanstate *newEncodedsequencescanstate(void);

void freeEncodedsequence(Encodedsequence **encseqptr);

void initEncodedsequencescanstate(Encodedsequencescanstate *esr,
                                  const Encodedsequence *encseq,
                                  Readmode readmode,
                                  Seqpos startpos);

void initEncodedsequencescanstategeneric(Encodedsequencescanstate *esr,
                                         const Encodedsequence *encseq,
                                         bool moveforward,
                                         Seqpos startpos);

void freeEncodedsequencescanstate(Encodedsequencescanstate **esr);

/*@null@*/ Encodedsequence *files2encodedsequence(
                                    bool withrange,
                                    const GtStrArray *filenametab,
                                    const Filelengthvalues *filelengthtab,
                                    bool plainformat,
                                    Seqpos totallength,
                                    unsigned long numofsequences,
                                    const Seqpos *specialrangestab,
                                    const Alphabet *alphabet,
                                    const char *str_sat,
                                    unsigned long *characterdistribution,
                                    Verboseinfo *verboseinfo,
                                    GtError *err);

/*@null@*/ Encodedsequence *mapencodedsequence(bool withrange,
                                               const GtStr *indexname,
                                               bool withesqtab,
                                               bool withdestab,
                                               bool withssptab,
                                               Verboseinfo *verboseinfo,
                                               GtError *err);

void checkallsequencedescriptions(const Encodedsequence *encseq);

unsigned long *calcdescendpositions(const Encodedsequence *encseq);

const char *retrievesequencedescription(unsigned long *desclen,
                                        const Encodedsequence *encseq,
                                        const unsigned long *descendtab,
                                        unsigned long seqnum);

Encodedsequence *plain2encodedsequence(bool withrange,
                                       const Uchar *seq1,
                                       Seqpos len1,
                                       const Uchar *seq2,
                                       unsigned long len2,
                                       const Alphabet *alpha,
                                       Verboseinfo *verboseinfo);

Specialrangeiterator *newspecialrangeiterator(const Encodedsequence *encseq,
                                              bool moveforward);

bool hasspecialranges(const Encodedsequence *encseq);

bool hasfastspecialrangeenumerator(const Encodedsequence *encseq);

bool possibletocmpbitwise(const Encodedsequence *encseq);

bool nextspecialrangeiterator(Sequencerange *range,Specialrangeiterator *sri);

void freespecialrangeiterator(Specialrangeiterator **sri);

/*@null@*/ const char *encseqaccessname(const Encodedsequence *encseq);

void encseqextract(Uchar *buffer,
                   const Encodedsequence *encseq,
                   Seqpos frompos,
                   Seqpos topos);

int multicharactercompare(const Encodedsequence *encseq,
                          bool fwd,
                          bool complement,
                          Encodedsequencescanstate *esr1,
                          Seqpos pos1,
                          Encodedsequencescanstate *esr2,
                          Seqpos pos2);

int compareEncseqsequences(Seqpos *lcp,
                           const Encodedsequence *encseq,
                           bool fwd,
                           bool complement,
                           Encodedsequencescanstate *esr1,
                           Encodedsequencescanstate *esr2,
                           Seqpos pos1,Seqpos pos2,
                           Seqpos depth);

/* some check functions called in test-encseq.c */

void checkextractunitatpos(const Encodedsequence *encseq,
                           bool fwd,bool complement);

void multicharactercompare_withtest(const Encodedsequence *encseq,
                                    bool fwd,
                                    bool complement,
                                    Encodedsequencescanstate *esr1,
                                    Seqpos pos1,
                                    Encodedsequencescanstate *esr2,
                                    Seqpos pos2);

void showsequenceatstartpos(FILE *fp,
                            bool fwd,
                            bool complement,
                            const Encodedsequence *encseq,
                            Seqpos startpos);

bool containsspecial(const Encodedsequence *encseq,
                     bool moveforward,
                     Encodedsequencescanstate *esrspace,
                     Seqpos startpos,
                     Seqpos len);

unsigned int getsatforcevalue(const char *str);

Seqpos *encseq2markpositions(const Encodedsequence *encseq);

void checkmarkpos(const Encodedsequence *encseq);

unsigned long getrecordnumSeqpos(const Seqpos *recordseps,
                                 unsigned long numofrecords,
                                 Seqpos totalwidth,
                                 Seqpos position);

const Seqpos *getencseqssptab(const Encodedsequence *encseq);

void getencseqSeqinfo(Seqinfo *seqinfo,const Encodedsequence *encseq,
                      unsigned long seqnum);

Seqpos getencseqspecialcharacters(const Encodedsequence *encseq);

Seqpos getencseqspecialranges(const Encodedsequence *encseq);

Seqpos getencseqrealspecialranges(const Encodedsequence *encseq);

Seqpos getencseqlengthofspecialprefix(const Encodedsequence *encseq);

Seqpos getencseqlengthofspecialsuffix(const Encodedsequence *encseq);

void setencseqspecialcharinfo(Encodedsequence *encseq,
                              const Specialcharinfo *specialcharinfo);

int readSpecialcharinfo(Specialcharinfo *specialcharinfo,
                        const GtStr *indexname,GtError *err);

unsigned int getencseqAlphabetmapsize(const Encodedsequence *encseq);

unsigned int getencseqAlphabetnumofchars(const Encodedsequence *encseq);

const Uchar *getencseqAlphabetsymbolmap(const Encodedsequence *encseq);

const Alphabet *getencseqAlphabet(const Encodedsequence *encseq);

const Uchar *getencseqAlphabetcharacters(const Encodedsequence *encseq);

void removealpharef(Encodedsequence *encseq);

const GtStrArray *getencseqfilenametab(const Encodedsequence *encseq);

const Filelengthvalues *getencseqfilelengthtab(const Encodedsequence *encseq);

void removefilenametabref(Encodedsequence *encseq);

#endif
