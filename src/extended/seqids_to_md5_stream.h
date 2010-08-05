/*
  Copyright (c) 2010 Gordon Gremme <gremme@zbh.uni-hamburg.de>

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

#ifndef SEQIDS_TO_MD5_STREAM_H
#define SEQIDS_TO_MD5_STREAM_H

#include <stdio.h>
#include "extended/node_stream_api.h"
#include "extended/region_mapping.h"

/* Implements the ``genome_stream'' interface. */
typedef struct GtSeqidsToMD5Stream GtSeqidsToMD5Stream;

const GtNodeStreamClass* gt_seqids_to_md5_stream_class(void);

/* Create a GtSeqidToMD5Stream, takes ownership of <region_mapping>. */
GtNodeStream*             gt_seqids_to_md5_stream_new(GtNodeStream *in_stream,
                                                      GtRegionMapping
                                                      *region_mapping);

#endif