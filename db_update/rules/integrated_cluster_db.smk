rule integrated_cluster_db:
    input:
        clu_cat = config["rdir"] + "/cluster_categories/cluster_ids_categ.tsv",
        clu_com = config["rdir"] + "/cluster_communities/cluster_communities.tsv",
        clu_stats = config["rdir"] + "/cluster_category_stats/cluster_category_summary_stats.tsv",
        hq_clu = config["rdir"] + "/cluster_category_stats/HQ_clusters.tsv",
        clu_hmm = config["rdir"] + "/cluster_category_DB/clu_hmm_db"
    threads: 7
    params:
        mmseqs_bin = config["mmseqs_bin"],
        mmseqs_tmp = config["mmseqs_tmp"],
        local_tmp   = config["mmseqs_local_tmp"],
        idir = config["rdir"] + "/integrated_cluster_DB",
        original = config["rdir"] + "/mmseqs_clustering/cluDB_original_name_rep_size.tsv",
        shared = config["rdir"] + "/mmseqs_clustering/cluDB_shared_name_rep_size.tsv",
        new = config["rdir"] + "/mmseqs_clustering/cluDB_new_name_rep_size.tsv",
        tmpl = config["rdir"] + "/integrated_cluster_DB/tmpl",
        clu_seq = config["rdir"] + "/cluster_categories/refined_clusterDB",
        clu_gene = config["rdir"] + "/cluster_categories/cluster_ids_categ_genes.tsv.gz",
        sp_sh = config["rdir"] + "/spurious_shadow/spurious_shadow_info.tsv",
        multi_annot = config["rdir"] + "/annot_and_clust/pfam_name_acc_clan_multi.tsv.gz",
        partial = config["rdir"] + "/gene_prediction/orf_partial_info.tsv",
        isp_sh = config["rdir"] + "/integrated_cluster_DB/spurious_shadow_info.tsv.gz",
        imulti_annot = config["rdir"] + "/integrated_cluster_DB/pfam_name_acc_clan_multi.tsv.gz",
        ipartial = config["rdir"] + "/integrated_cluster_DB/orf_partial_info.tsv.gz",
        iclu_gene = config["rdir"] + "/integrated_cluster_DB/cluster_ids_categ_genes.tsv.gz",
        clu_origin = config["rdir"] + "/integrated_cluster_DB/cluDB_name_origin_size.tsv",
        or_clu_orig = config["ordir"] + "/cluDB_name_origin_size.tsv.gz",
        or_clu_cat = config["ordir"] + "/cluster_ids_categ.tsv.gz",
        or_clu_gene = config["ordir"] + "/cluster_ids_categ_genes.tsv.gz",
        or_clu_com = config["ordir"] + "/cluster_communities.tsv.gz",
        or_clu_stats = config["ordir"] + "/cluster_category_summary_stats.tsv.gz",
        or_hq_clu = config["ordir"] + "/HQ_clusters.tsv.gz",
        or_clu_hmm = config["profile_dir"] + "/clu_hmm_db",
        or_clu_seq = config["cluseqdb_dir"] + "/clu_seqDB",
        or_partial = config["ordir"] + "/orf_partial_info.tsv.gz"
    log:
        out = "logs/integ_stdout.log",
        err = "logs/integ_stderr.err"
    benchmark:
        "benchmarks/integrated_cluster_DB/integdb.tsv"
    output:
        iclu_cat = config["rdir"] + "/integrated_cluster_DB/cluster_ids_categ.tsv",
        iclu_com = config["rdir"] + "/integrated_cluster_DB/cluster_communities.tsv",
        iclu_stats = config["rdir"] + "/integrated_cluster_DB/cluster_category_summary_stats.tsv",
        ihq_clu = config["rdir"] + "/integrated_cluster_DB/HQ_clusters.tsv",
        iclu_hmm = config["rdir"] + "/integrated_cluster_DB/mmseqs_profiles/clu_hmm_db",
        iclu_seq = config["rdir"] + "/integrated_cluster_DB/mmseqs_cluseqdb/clu_seqDB"
    shell:
        """

        set -x
        set -e

        DIR=$(dirname {output.iclu_hmm})

        mkdir -p ${{DIR}}

        # Summary table with cluster db origin (original/shared/new)
        join -11 -21 <(zcat {params.or_clu_orig} | awk '{{print $1,$2}}' | sort -k1,1 --parallel={threads} ) \
            <(awk '{{print $1,$3}}' {params.original} | sort -k1,1) > {params.clu_origin}
        join -11 -21 <(zcat {params.or_clu_orig} | awk '{{print $1,$2}}' |  sort -k1,1 --parallel={threads} ) \
            <(awk '{{print $1,$3}}' {params.shared} | sort -k1,1) > {params.clu_origin}.temp
        awk '{{print $1,$2"_new",$3}}' {params.clu_origin}.temp >> {params.clu_origin}
        awk '{{print $1,"new",$3}}' {params.new} >> {params.clu_origin}
        rm {params.clu_origin}.temp
        sed -i 's/ /\t/g' {params.clu_origin}

        # All gene headers and partiality information
        cat {params.partial} <(zcat {params.or_partial}) | gzip > {params.ipartial}

        # Spurious and shadow genes information:
        gzip -c {params.sp_sh} > {params.isp_sh}

        # All gene Pfam annotations:
        cp {params.multi_annot} {params.imulti_annot}

        # All cluster category annotation files
        ODIR=$(dirname {params.or_clu_cat})
        NDIR=$(dirname {input.clu_cat})

        cat <(zcat ${{ODIR}}/K_annotations.tsv.gz) ${{NDIR}}/K_annotations.tsv | gzip > {params.idir}/K_annotations.tsv.gz
        cat <(zcat ${{ODIR}}/KWP_annotations.tsv.gz) ${{NDIR}}/KWP_annotations.tsv | gzip > {params.idir}/KWP_annotations.tsv.gz
        cat <(zcat ${{ODIR}}/GU_annotations.tsv.gz) ${{NDIR}}/GU_annotations.tsv | gzip > {params.idir}/GU_annotations.tsv.gz

        # Integrated set of cluster categories
        cat <(zcat {input.clu_cat}) {params.or_clu_cat} > {output.iclu_cat}

        # and the cluster genes
        zcat {params.clu_gene} {params.or_clu_gene} | gzip > {params.iclu_gene}

        # Integrated set of cluster communities
        # to avoid having overlapping communities names, we append the dataset origin
        cat <(awk -vOFS='\\t' 'NR>1{{print $1,$2"_new",$3}}' {input.clu_com} ) \
         <( awk -vOFS='\\t' 'NR>1{{print $1,$2"_or",$3}}' <(zcat {params.or_clu_com})) > {output.iclu_com}

        echo -e "cl_name\tcom\tcategory" | cat - {output.iclu_com} > {params.tmpl} && mv {params.tmpl} {output.iclu_com}

        # Integrated cluster summary information
        cat {input.clu_stats} <(zcat {params.or_clu_stats} | awk -vOFS='\\t' 'NR>1{{print $0}}') > {output.iclu_stats}

        # Integrated set of high quality (HQ) clusters
        cat {input.hq_clu} <(zcat {params.or_hq_clu} | awk -vOFS='\\t' 'NR>1{{print $0}}' ) > {output.ihq_clu}

        # New integarted cluster HMMs DB (for MMseqs profile searches)
        ### add the wget and tar -xzvf mmseqs-profile (change params)
        {params.mmseqs_bin} concatdbs {input.clu_hmm} {params.or_clu_hmm} {output.iclu_hmm} --threads 1 2>{log.err}
        {params.mmseqs_bin} concatdbs {input.clu_hmm}_h {params.or_clu_hmm}_h {output.iclu_hmm}_h --threads 1 2>{log.err}

        # New integarted cluster sequence DB (MMseqs sequence database with clustered index)
        {params.mmseqs_bin} concatdbs {params.clu_seq} {params.or_clu_seq} {output.iclu_seq} --threads 1 2>{log.err}

        """

rule integrated_cludb_done:
    input:
        iclu_cat = config["rdir"] + "/integrated_cluster_DB/cluster_ids_categ.tsv",
        iclu_com = config["rdir"] + "/integrated_cluster_DB/cluster_communities.tsv",
        iclu_stats = config["rdir"] + "/integrated_cluster_DB/cluster_category_summary_stats.tsv",
        ihq_clu = config["rdir"] + "/integrated_cluster_DB/HQ_clusters.tsv",
        iclu_hmm = config["rdir"] + "/integrated_cluster_DB/cluster_category_DB/clu_hmm_db",
        iclu_seq = config["rdir"] + "/integrated_cluster_DB/cluster_category_DB/clu_seqDB"
    output:
        integdb_done = touch(config["rdir"] + "/integrated_cluster_DB/integdb.done")
    run:
        shell("echo 'INTEGRATED DB DONE'")
