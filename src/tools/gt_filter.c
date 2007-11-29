/*
  Copyright (c) 2005-2007 Gordon Gremme <gremme@zbh.uni-hamburg.de>
  Copyright (c) 2005-2007 Center for Bioinformatics, University of Hamburg

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

#include "libgtcore/option.h"
#include "libgtcore/outputfile.h"
#include "libgtcore/undef.h"
#include "libgtcore/versionfunc.h"
#include "libgtext/filter_stream.h"
#include "libgtext/gff3_in_stream.h"
#include "libgtext/gff3_out_stream.h"

typedef struct {
  bool verbose;
  Str *seqid,
      *typefilter;
  unsigned long max_gene_length,
                max_gene_num;
  double min_gene_score;
  GenFile *outfp;
} FilterArgumentss;

static OPrval parse_options(int *parsed_args, FilterArgumentss *arguments,
                            int argc, const char **argv, Error *err)
{
  OptionParser *op;
  OutputFileInfo *ofi;
  Option *option;
  OPrval oprval;
  error_check(err);

  /* init */
  op = option_parser_new("[option ...] [GFF3_file ...]", "Filter GFF3 files.");
  ofi = outputfileinfo_new();

  /* -seqid */
  option = option_new_string("seqid", "seqid a feature must have to pass the "
                             "filter (excluding comments)", arguments->seqid,
                             NULL);
  option_parser_add_option(op, option);

  /* -typefilter */
  option = option_new_string("typefilter", "filter out all features of the "
                             "given type", arguments->typefilter, NULL);
  /* XXX */
  option_is_development_option(option);
  option_parser_add_option(op, option);

  /* -maxgenelength */
  option = option_new_ulong_min("maxgenelength", "the maximum length a gene "
                                "can have to pass the filter",
                                &arguments->max_gene_length, UNDEF_ULONG, 1);
  option_parser_add_option(op, option);

  /* -maxgenenum */
  option = option_new_ulong("maxgenenum", "the maximum number of genes which "
                            "can pass the filter", &arguments->max_gene_num,
                            UNDEF_ULONG);
  option_parser_add_option(op, option);

  /* -mingenescore */
  option = option_new_double("mingenescore", "the minimum score a gene must "
                             "have to pass the filter",
                             &arguments->min_gene_score, UNDEF_DOUBLE);
  option_parser_add_option(op, option);

  /* -v */
  option = option_new_verbose(&arguments->verbose);
  option_parser_add_option(op, option);

  /* output file options */
  outputfile_register_options(op, &arguments->outfp, ofi);

  /* parse options */
  oprval = option_parser_parse(op, parsed_args, argc, argv, versionfunc, err);

  /* free */
  outputfileinfo_delete(ofi);
  option_parser_delete(op);

  return oprval;
}

int gt_filter(int argc, const char **argv, Env *env)
{
  GenomeStream *gff3_in_stream, *filter_stream, *gff3_out_stream;
  GenomeNode *gn;
  FilterArgumentss arguments;
  int parsed_args, had_err;

  /* option parsing */
  arguments.seqid = str_new();
  arguments.typefilter = str_new();
  switch (parse_options(&parsed_args, &arguments, argc, argv, env_error(env))) {
    case OPTIONPARSER_OK: break;
    case OPTIONPARSER_ERROR:
      str_delete(arguments.seqid);
      str_delete(arguments.typefilter);
      return -1;
    case OPTIONPARSER_REQUESTS_EXIT:
      str_delete(arguments.seqid);
      str_delete(arguments.typefilter);
      return 0;
  }

  /* create a gff3 input stream */
  gff3_in_stream = gff3_in_stream_new_unsorted(argc - parsed_args,
                                               argv + parsed_args,
                                               arguments.verbose &&
                                               arguments.outfp, false);

  /* create a filter stream */
  filter_stream = filter_stream_new(gff3_in_stream, arguments.seqid,
                                    arguments.typefilter,
                                    arguments.max_gene_length,
                                    arguments.max_gene_num,
                                    arguments.min_gene_score);

  /* create a gff3 output stream */
  gff3_out_stream = gff3_out_stream_new(filter_stream, arguments.outfp);

  /* pull the features through the stream and free them afterwards */
  while (!(had_err = genome_stream_next_tree(gff3_out_stream, &gn,
                                             env_error(env))) && gn) {
    genome_node_rec_delete(gn);
  }

  /* free */
  genome_stream_delete(gff3_out_stream);
  genome_stream_delete(filter_stream);
  genome_stream_delete(gff3_in_stream);
  genfile_close(arguments.outfp);
  str_delete(arguments.seqid);
  str_delete(arguments.typefilter);

  return had_err;
}
