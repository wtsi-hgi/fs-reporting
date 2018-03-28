#!/usr/bin/env bash

# Create Sanger-Specific Mappings
# Christopher Harrison <ch12@sanger.ac.uk>

set -euo pipefail

BINARY="$(readlink -fn "$0")"
WORK_DIR="$(dirname "${BINARY}")"

declare -a GROUPS=(
  # Human Genetics Programme Unix groups
  # Loosely derived from LSF config, as of 2018-03-28
  adpdcrispr adrp1 afd_trios afr100k agv aiexomes ameliaqt amish-coreex
  ancient-american ancient-botai ancientdna ancientgen ancient-hinxton
  ancient-horses ancient-neolith ancient-steppe ancient-vikings an-core
  anpopgen arcogen_coreex argo-gwas asd-nor-trio atac_gut_blood atac_seq
  ausgen autozyg blood_mt bowelprep cardiogram-c4d carl_seq
  caucasus_popgen cffdna cg_validate chad_xten chd chd_brook cichlid
  cloten coloc_and_fm coreex_pbc cri-detect crohns ctcf ddd
  ddd_mouse2016 ddd_thra devxomes dnmscz eastern_gorilla ehrgen
  esgi-cilentogen esgi-dalmatians esgi-isolatexome esgi-mitoexome
  esgi-ngsinctc esgi-pcd esgi-vbseq fintwin_combo flu_exomes fpld1_geno
  ftp-team147 ftp-team149 ftp-team29 fvg_seq g1k-fig g1k-sv g1k-ycnv
  gambian_fula gdap_hla gdap-wgs gel-ann go-nl graphs grit gwava
  hb_e_beta_thal helic helic_design hematopoiesis hgdp_wgs hgi
  hgi-wgs-dev himalaya-popgen hipsci hiseqx_test hiv_exomes host_virus
  hrc human_evol_3b humevol15 hum_evol_3 humgen-10x-pilot ibd ibd_colors
  ibd_eqtl ibdgwas ibdmicro ibd_wes ibdx10 ichip ihac ihgc imd
  inter_preg_gen interval_cnv interval_gwas interval_rm18 interval_wes
  interval_wgs int_wes_metabol intwes_nmr_lipid isolates jk_wgs kuusamo
  lebanon lvoto_rep methyl-ddd migraine miscarriage_gwas mouse_epi msmc
  mtbolite mu mus3g muspa musperm muther_mqtl njr_ddh oceania-10x odex
  orcades osteolysis ot_airways otcoregen oxfordibd p647_reseq pagedata
  patagonian paxgene pd_rnaseq phd_as31 pneumo-inf project_india
  promis_rna_seq psc2020 pscmeta psorsfm rahman1958exome rnaafr
  rna_stanislas rvfs s_am_popgen scd scg_sperm setd1a_mouse sga
  sgachildren_wes sir_wes sle-ibd statin_exp t144_acst t144_anno
  t144_arcogen t144_bright_bp t144_fungenqq t144_gomap t144_helic_15x
  t144_helic_ug t144_hip_fungen t144_isolates t144_metal_meth
  t144_nargwas t144_oa_exomes t144_oagwas_meta t144-phenotypes
  t144_pleiotropy t144_podo t144_silc t144_silc_grland t144_silc_orkney
  t144_teenage t144_teenage_gt t144_usoc t149_apcdr t149_legal
  t149_restricted t151_shapeit3 t156-anosmia t19-asli t19-ethiopia
  t19-napg t19-ooa t19_popgen_x10 t19-rrseq t1d_cnv t29_miseq_models
  t2d_1q t35_gluinsrt t35_lyplal1 t35_magic t35_overlap t35_scoop
  t35_statin_hep t35_uk10k_mito tb team111 team128 team135 team143
  team144 team147 team149 team151 team152 team152_bce team19 team190
  team191 team192 team193 team195 team224 team29 team35 th17pilot
  tibet_pg trachoma trans_ethnic_sim ug2g uganda uganda_gwas ugvac uk10k
  uk10k-expression ukabc ukbb500k_t151 ukbb_autozyg ukbb_celiac
  ukbb_int_phewas ukbb_obesity ukbiobank ukbiobank_cardmet
  ukbiobank_cmc_hba1c ukbiobank_cmc_t2d ukbiobank_oa ukbiobank_t151
  ukexomechip vaccgene wes-thyroid wgs_kazuzb wish_wes wtccc3_rtd
  www-t143 yemen_chad_geno yo-psc y_phylogeny_de zuluds zulu_wgs
)

declare -a PIS=(
  # Human Genetics Programme PIs
  ca3 cts em13 ez1 ib1 kj2 meh ms23 ns6  # Current
  ap8 jb26 panos rd rm2                  # Past
)

create_pi_mapping() {
  # Create group to PI user ID mapping from LDAP and heuristics
  # TODO
  true
}

create_user_mapping() {
  # Create user mapping from the passwd database
  getent passwd | awk 'BEGIN { FS = ":"; OFS = "\t" } { print $4, $1, $5 }'
}

create_group_mapping() {
  # Create group mapping from the group database,
  # restricted to predefined humgen groups
  getent group "${GROUPS[@]}" | awk 'BEGIN { FS = ":"; OFS = "\t" } { print $3, $1 }'
}

main() {
  local -i force=0
  while (( $# )); do
    if [[ "$1" == "--force" ]]; then
      force=1
    fi
  done

  local pi_map="${WORK_DIR}/gid-pi_uid.map"
  local user_map="${WORK_DIR}/uid-user.map"
  local group_map="${WORK_DIR}/gid-group.map"

  # Warn the user if mappings already exist without --force supplied
  if ! (( force )); then
    if [[ -e "${pi_map}" ]] || [[ -e "${user_map}" ]] || [[ -e "${group_map}" ]]; then
      >&2 echo "Some or all mappings already exist. Either back them up, or rerun this with the --force option."
      exit 1
    fi
  fi

  # Delete old mappings
  rm -f "${pi_map}" "${user_map}" "${group_map}"

  create_pi_mapping    > "${pi_map}"
  create_user_mapping  > "${user_map}"
  create_group_mapping > "${group_map}"
}

main "$@"
