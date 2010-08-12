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

#include "extended/md5_to_seqids_stream.h"
#include "extended/md5_to_seqids_visitor.h"
#include "extended/node_stream_api.h"

struct GtMD5ToSeqidsStream {
  const GtNodeStream parent_instance;
  GtNodeStream *in_stream;
  GtNodeVisitor *md5_to_seqids_visitor;
};

#define md5_to_seqids_stream_cast(GS)\
        gt_node_stream_cast(gt_md5_to_seqids_stream_class(), GS)

static int md5_to_seqids_stream_next(GtNodeStream *ns, GtGenomeNode **gn,
                                     GtError *err)
{
  GtMD5ToSeqidsStream *md5_to_seqids_stream;
  int had_err;
  gt_error_check(err);
  md5_to_seqids_stream = md5_to_seqids_stream_cast(ns);
  had_err = gt_node_stream_next(md5_to_seqids_stream->in_stream, gn, err);
  if (!had_err && *gn) {
    had_err = gt_genome_node_accept(*gn,
                                    md5_to_seqids_stream->md5_to_seqids_visitor,
                                    err);
  }
  if (had_err) {
    /* we own the node -> delete it */
    gt_genome_node_delete(*gn);
    *gn = NULL;
  }
  return had_err;
}

static void md5_to_seqids_stream_free(GtNodeStream *ns)
{
  GtMD5ToSeqidsStream *md5_to_seqids_stream = md5_to_seqids_stream_cast(ns);
  gt_node_visitor_delete(md5_to_seqids_stream->md5_to_seqids_visitor);
  gt_node_stream_delete(md5_to_seqids_stream->in_stream);
}

const GtNodeStreamClass* gt_md5_to_seqids_stream_class(void)
{
  static const GtNodeStreamClass *nsc = NULL;
  if (!nsc) {
    nsc = gt_node_stream_class_new(sizeof (GtMD5ToSeqidsStream),
                                   md5_to_seqids_stream_free,
                                   md5_to_seqids_stream_next);
  }
  return nsc;
}

GtNodeStream* gt_md5_to_seqids_stream_new(GtNodeStream *in_stream,
                                          GtRegionMapping *rm)
{
  GtMD5ToSeqidsStream *md5_to_seqids_stream;
  GtNodeStream *ns;
  ns = gt_node_stream_create(gt_md5_to_seqids_stream_class(), true);
  md5_to_seqids_stream = md5_to_seqids_stream_cast(ns);
  md5_to_seqids_stream->in_stream = gt_node_stream_ref(in_stream);
  md5_to_seqids_stream->md5_to_seqids_visitor =
    gt_md5_to_seqids_visitor_new(rm);
  return ns;
}