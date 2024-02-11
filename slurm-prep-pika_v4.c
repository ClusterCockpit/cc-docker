/*****************************************************************************\
 *  prep_script.c - PrEp script plugin, handles Prolog / Epilog /
 *		    PrologSlurmctld / EpilogSlurmctld scripts
 *****************************************************************************
 *  Written by Mike Arnhold and Frank Winkler
 *
 *  https://gitlab.hrz.tu-chemnitz.de/pika/pika-packages/-/raw/master/pika-prep-plugin/slurm-prep-pika_v4.c
\*****************************************************************************/

#include <stdarg.h>
#include <unistd.h>
#include <inttypes.h>

#include <nats/nats.h>

#include "slurm/slurm.h"
#include "slurm/slurm_errno.h"
#include "src/common/prep.h"
#include "src/common/macros.h"
#include "src/common/xmalloc.h"
#include "src/common/xstring.h"
#include "src/common/parse_time.h"
#include "src/common/uid.h"


#define P_NAME "PrEp-pika: "
#define BUFF_LEN 128
#define MAX_STR_LEN 10240	/* 10 KB */

const char plugin_name[] = "PrEp plugin pika";
const char plugin_type[] = "prep/pika";
const uint32_t plugin_version = SLURM_VERSION_NUMBER;


static bool have_prolog_slurmctld = false;
static bool have_epilog_slurmctld = false;

void (*prolog_slurmctld_callback)(int rc, uint32_t job_id) = NULL;
void (*epilog_slurmctld_callback)(int rc, uint32_t job_id) = NULL;

char *prefix = "JOB_RECORD__";
char *exclude_keys_prolog = "";
char *exclude_keys_epilog = "";
static pthread_mutex_t  plugin_log_lock = PTHREAD_MUTEX_INITIALIZER;

typedef enum {
	PROLOG = 0,
	EPILOG = 1
} context_t;


/**************************
 * json helper data types *
 **************************/
typedef enum
{
	SUCCESS = 0,
	E_JSON_OUT_OF_MEMORY = -2,
	E_HOST_LIST_SHIFT = -3,
	E_HOST_LIST_CREATE = -4,
	E_PREFIX_PREPEND = -5,
} internal_error_t;

typedef enum
{
	NONE = -1,
	U16,
	U32,
	U64,
	U16PP,
	CHARPP,
	CHARP,
	TIMEP,
} value_type_t;

typedef struct {
	uint16_t **items;
	uint16_t *item_counts;  // common type for sub count in slurm?
	uint32_t count;         // common type for over all count in slurm?
} uint16_2d_t;

typedef struct {
	char **items;
	int count;
} char_2d_t;

typedef union
{
	uint16_t uint16;
	uint32_t uint32;
	uint64_t uint64;
	char *charp;
	char_2d_t charpp;
	uint16_2d_t uint16pp;
	time_t *timep;
} value_t;

typedef struct
{
	job_record_t *job_ptr;
	char * job_name;
	uint64_t mem_per_cpu;
	uint64_t mem_per_node;
	uint16_t **ids;
	uint16_t *id_cnts;
	char **node_names;
	int name_cnt;
	char *user;
	char *job_state;
	uint32_t gpu_alloc_cnt;
	uint16_t smt_enabled;
	char *job_script;
	uint32_t core_cnt;
} prep_t;

typedef struct key_value_pair key_value_pair_t;
struct key_value_pair
{
	char *key;
	value_type_t type;
	void (*get_value)(key_value_pair_t *, prep_t *);
	value_t value;
	bool collect[2];
};

key_value_pair_t *collect;

/*************************
 * function declarations *
 *************************/
/* Added spank_like output functions for convenience */
extern void slurm_info (const char *format, ...)
    __attribute__ ((format (printf, 1, 2)));
extern void slurm_error (const char *format, ...)
    __attribute__ ((format (printf, 1, 2)));
extern void slurm_verbose (const char *format, ...)
    __attribute__ ((format (printf, 1, 2)));
extern void slurm_debug (const char *format, ...)
    __attribute__ ((format (printf, 1, 2)));
extern void slurm_debug2 (const char *format, ...)
    __attribute__ ((format (printf, 1, 2)));
extern void slurm_debug3 (const char *format, ...)
    __attribute__ ((format (printf, 1, 2)));

/* Forward declerations */
static int job_ptr_to_json(job_record_t *job_ptr, char **json, context_t cntxt);
static const char *error_to_string(internal_error_t error);
static int copy_key_value_pairs(key_value_pair_t *dst,
                                key_value_pair_t *src,
                                size_t size);

static int pika_metadata_log(int job_id, char *json, bool is_epilog);

/* Helper macro.
 * Uses _expr (usually an expression returning a number/error)
 * to either advance an offset value _o by that number or
 * return the number as error _e if it is negative */
#define ADVANCE_OR_RETURN(_o, _e, _expr) \
{\
	_e = _expr; \
	if (_e < 0) return _e; \
	else _o += _e; \
}

/* Anonymous function macro. Requires GNU C extensions (gcc).
 * Provide a boidy for the key_value_pair_t get_value callback.
 * The injected parameter names:
 * - key_value_pair_t: kvp
 * - prep_t: prep
 */
#define VALUE_CB(body) \
({ \
	void __fn__ (key_value_pair_t *kvp, prep_t *prep) { body } \
	__fn__; \
})

/**************
 * plugin api *
 **************/
extern int init(void)
{
	slurm_info(P_NAME "init\n");

	key_value_pair_t collectables[] = {
		{"ARRAY_ID", U32, VALUE_CB(
			kvp->value.uint32=prep->job_ptr->array_job_id;
		)},
		{"JOB_NAME", CHARP, VALUE_CB(
			kvp->value.charp=prep->job_name;
		)},
		{"USER_ID", U32, VALUE_CB(
			kvp->value.uint32=prep->job_ptr->user_id;
		)},
		{"ACCOUNT", CHARP, VALUE_CB(
			kvp->value.charp=prep->job_ptr->account;
		)},
		{"WORK_DIR", CHARP, VALUE_CB(
			kvp->value.charp=prep->job_ptr->details->work_dir;
		)},
		{"PARTITION", CHARP, VALUE_CB(
			kvp->value.charp=prep->job_ptr->partition;
		)},
		{"CPU_CNT", U32, VALUE_CB(
			kvp->value.uint32=prep->job_ptr->job_resrcs->ncpus;
		)},
		{"CPU_IDS", U16PP, VALUE_CB(
			kvp->value.uint16pp.items=prep->ids;
			kvp->value.uint16pp.item_counts=prep->id_cnts;
			kvp->value.uint16pp.count=prep->job_ptr->job_resrcs->nhosts;
		)},
		{"NODE_CNT", U32, VALUE_CB(
			kvp->value.uint32=prep->job_ptr->job_resrcs->nhosts;
		)},
		{"NODE_NAMES", CHARPP, VALUE_CB(
			kvp->value.charpp.items=prep->node_names;
			kvp->value.charpp.count=prep->name_cnt;
		)},
		{"MEM_PER_CPU", U64, VALUE_CB(
			kvp->value.uint64=prep->mem_per_cpu;
		)},
		{"MEM_PER_NODE", U64, VALUE_CB(
			kvp->value.uint64=prep->mem_per_node;
		)},
		{"TIME_LIMIT", U32, VALUE_CB(
			kvp->value.uint32=prep->job_ptr->time_limit;
		)},
		{"WHOLE_NODE", U16, VALUE_CB(
			kvp->value.uint16=prep->job_ptr->details->whole_node;
		)},
		{"COMMENT", CHARP, VALUE_CB(
			kvp->value.charp=prep->job_ptr->comment;
		)},
		{"START_TIME", TIMEP, VALUE_CB(
			kvp->value.timep=&(prep->job_ptr->start_time);
		)},
		{"USER", CHARP, VALUE_CB(
			kvp->value.charp=prep->user;
		)},
		{"PARTITION_NAME", CHARP, VALUE_CB(
			kvp->value.charp=prep->job_ptr->part_ptr->name;
		)},
		{"BILLABLE_CORES", U32, VALUE_CB(
			kvp->value.uint32=(int)(prep->job_ptr->billable_tres);
		)},
		{"SMT_ENABLED", U16, VALUE_CB(
			kvp->value.uint16=prep->smt_enabled;
		)},
		{"GPU_ALLOC_CNT", U32, VALUE_CB(
			kvp->value.uint32=prep->gpu_alloc_cnt;
		)},
		{"SUBMIT_TIME", TIMEP, VALUE_CB(
			kvp->value.timep=&(prep->job_ptr->details->submit_time);
		)},
		{"END_TIME", TIMEP, VALUE_CB(
			kvp->value.timep=&(prep->job_ptr->end_time);
		)},
		{"JOB_STATE", CHARP, VALUE_CB(
			kvp->value.charp=prep->job_state;
		)},
		{"GRES_DETAIL_STR", CHARPP, VALUE_CB(
			kvp->value.charpp.items=prep->job_ptr->gres_detail_str;
			kvp->value.charpp.count=prep->job_ptr->gres_detail_cnt;
		)},
		{"BATCH_FEATURES", CHARP, VALUE_CB(
			kvp->value.charp=prep->job_ptr->batch_features;
		)},
		{"ARGV", CHARPP, VALUE_CB(
			kvp->value.charpp.items=prep->job_ptr->details->argv;
			kvp->value.charpp.count=prep->job_ptr->details->argc;
		)},
		{"JOB_SCRIPT", CHARP, VALUE_CB(
			kvp->value.charp=prep->job_script;
		)},
		{"CORE_CNT", U32, VALUE_CB(
			kvp->value.uint32=prep->core_cnt;
		)},
		{"SPANK_JOB_ENV", CHARPP, VALUE_CB(
			kvp->value.charpp.items=prep->job_ptr->spank_job_env;
			kvp->value.charpp.count=prep->job_ptr->spank_job_env_size;
		)},
		{NULL, NONE},
	};
	size_t size = sizeof(collectables)/sizeof(key_value_pair_t);
	collect = xmalloc(sizeof(key_value_pair_t) * size);
	// store_conf_values_or_defaults();
	int rc = copy_key_value_pairs(collect, collectables, size);
	if (rc) {
		slurm_error(P_NAME "%s", error_to_string(rc));
    	return SLURM_ERROR;
	}
	return SLURM_SUCCESS;
}

extern void fini(void)
{
	key_value_pair_t *ptr = collect;
	if (ptr) {
		while (ptr->key) {
			xfree(ptr->key);
		}
		xfree(collect);
	}
}

extern void prep_p_register_callbacks(prep_callbacks_t *callbacks)
{
	/*
	 * Cannot safely run these without a valid callback, so disable
	 * them.
	 */

	if (!(prolog_slurmctld_callback = callbacks->prolog_slurmctld))
		have_prolog_slurmctld = false;
	if (!(epilog_slurmctld_callback = callbacks->epilog_slurmctld))
		have_epilog_slurmctld = false;
}

extern int prep_p_prolog(job_env_t *job_env, slurm_cred_t *cred)
{
    printf("Started job id: %d\n", job_env->jobid);

	job_info_msg_t *job_info_ptr = NULL;
	int rc;

	printf("%s: jobs handler called", __func__);

	rc = slurm_load_job(&job_info_ptr, job_env->jobid, SHOW_ALL | SHOW_DETAIL);

	if (rc == SLURM_ERROR || rc == SLURM_UNEXPECTED_MSG_ERROR) {
		printf("Unable to query job: %d\n", job_env->jobid);
		slurm_free_job_info_msg(job_info_ptr);

		return SLURM_ERROR;
	}

	ctxt_t *ctxt = NULL;
	// init_connection(context_id, method, parameters, query, tag, resp, auth);
	DATA_DUMP(ctxt->parser, JOB_INFO_MSG, *job_info_ptr,
		  data_key_set(resp, "jobs"));

	slurm_free_job_info_msg(job_info_ptr);

	return SLURM_SUCCESS;
}

extern int prep_p_epilog(job_env_t *job_env, slurm_cred_t *cred)
{
    printf("Ended job id: %d, exit code: %d\n", job_env->jobid, job_env->exit_code);
	return SLURM_SUCCESS;
}

extern int prep_p_prolog_slurmctld(job_record_t *job_ptr, bool *async)
{
    int rc = SLURM_SUCCESS;

    char* user = uid_to_string_or_null(job_ptr->user_id);
    if ( strcmp(user, "fwinkler") != 0 &&
         strcmp(user, "rotscher") != 0 ) {
        xfree(user);
        return rc;
    }
    xfree(user);

    slurm_info(P_NAME "prep_p_prolog_slurmctld\n");
    char *json;
    internal_error_t _rc = job_ptr_to_json(job_ptr, &json, false);
    if (_rc) {
        slurm_error(P_NAME "%s", error_to_string(_rc));
        rc = SLURM_ERROR;
    }

    *async = have_prolog_slurmctld;
    if (*async) {
        /* MUST run before async task finishes */
        prolog_slurmctld_callback(rc, job_ptr->job_id);
    }

    // Some async task
    if (rc == SLURM_SUCCESS) {
        pika_metadata_log(job_ptr->job_id, json, false);

		natsConnection *nc  = NULL;
		natsSubscription *sub = NULL;

		// Connects to the default NATS Server running locally
		natsConnection_ConnectTo(&nc, NATS_DEFAULT_URL);

		// Simple publisher to send the given json string to subject "slurm_start_job"
		natsConnection_PublishString(nc, "slurm_start_job", json);

		natsSubscription_Destroy(sub);
		natsConnection_Close(nc);
    }

    return rc;
}

extern int prep_p_epilog_slurmctld(job_record_t *job_ptr, bool *async)
{
    int rc = SLURM_SUCCESS;

    char* user = uid_to_string_or_null(job_ptr->user_id);
    if ( strcmp(user, "fwinkler") != 0 &&
         strcmp(user, "rotscher") != 0 ) {
        xfree(user);
        return rc;
    }
    xfree(user);

    slurm_info(P_NAME "prep_p_epilog_slurmctld\n");
    char *json;
    internal_error_t _rc = job_ptr_to_json(job_ptr, &json, true);
    if (_rc) {
        slurm_error(P_NAME "%s", error_to_string(_rc));
        rc = SLURM_ERROR;
    }

    *async = have_epilog_slurmctld;
    if (*async) {
        /* MUST run before async task finishes */
        epilog_slurmctld_callback(rc, job_ptr->job_id);
    }

    // Some async task
    if (rc == SLURM_SUCCESS) {
        pika_metadata_log(job_ptr->job_id, json, true);
    }

    return rc;
}


extern void prep_p_required(prep_call_type_t type, bool *required)
{
	*required = false;
	switch (type) {
	case PREP_PROLOG_SLURMCTLD:
		if (running_in_slurmctld())
			*required = true;
		break;
	case PREP_EPILOG_SLURMCTLD:
		if (running_in_slurmctld())
			*required = true;
		break;
	case PREP_PROLOG:
	case PREP_EPILOG:
		if (running_in_slurmd())
			*required = true;
		break;
	default:
		return;
	}

	return;
}


/**
 * Return string representation of error.
 */
static const char *error_to_string(internal_error_t error)
{
	switch (error) {
		case SUCCESS:
			return "success";
		case E_JSON_OUT_OF_MEMORY:
			return "ran out of memory when building json string";
		case E_HOST_LIST_SHIFT:
		case E_HOST_LIST_CREATE:
			return "failed to retrieve node names";
		case E_PREFIX_PREPEND:
			return "failed to prepend prefix to keys";
		default:
			return "unknown error";
	}
}

/**
 * Infer per cpu or per node cpus usage. Unused values will be set to NO_VAL64.
 */
static void get_memory(job_record_t *job_ptr, prep_t *preps)
{
	uint64_t pn_min_memory = job_ptr->details->pn_min_memory;
    preps->mem_per_cpu = NO_VAL64;
    preps->mem_per_node = NO_VAL64;
	if (pn_min_memory & MEM_PER_CPU){
		preps->mem_per_cpu = pn_min_memory & ~MEM_PER_CPU;
	} else {
		preps->mem_per_node = pn_min_memory;
	}
}

/**
 * Read the job resource core bitmap to infer cpu ids.
 */
static int get_cpu_ids(job_record_t *job_ptr, prep_t *prep)
{
	int rc = SLURM_SUCCESS;
	job_resources_t *job_resrcs = job_ptr->job_resrcs;
	uint16_t ncores = 0;
	uint32_t nhosts = job_resrcs->nhosts;
	uint32_t reps_remain = 0;
	int h, c, b, sock_ind;
	bitoff_t offset;
	bitstr_t *bitmap = job_resrcs->core_bitmap;

	prep->ids = xmalloc(sizeof(uint16_t*) * nhosts);
	prep->id_cnts = xmalloc(sizeof(uint16_t) * nhosts);
	for(h = 0, sock_ind = 0, offset = 0; h < nhosts && !rc; ++h){
		if(reps_remain == 0){
			reps_remain = job_resrcs->sock_core_rep_count[sock_ind];
			ncores = job_resrcs->sockets_per_node[sock_ind] *
			         job_resrcs->cores_per_socket[sock_ind];
			++sock_ind;
		}
		--reps_remain;
		prep->ids[h] = xmalloc(sizeof(uint16_t) * ncores);
		for(c = 0, b = 0; c < ncores && b < ncores; ++b){
			if(bit_test(bitmap, b + offset)){
				prep->ids[h][c++] = b;
			}
		}
		prep->id_cnts[h] = c;
		offset += ncores;
	}

	prep->core_cnt = 0;
	for (h = 0; h < nhosts; ++h) {
		prep->core_cnt += prep->id_cnts[h];
	}
	return rc;
}

/**
 * Get node names as array by splitting the job resource nodes string.
 */
static int get_nodes_names(job_record_t *job_ptr, prep_t *prep)
{
	int rc = 0, i;
	char *host;
	hostlist_t hl;
	if ((hl = slurm_hostlist_create(job_ptr->job_resrcs->nodes))) {
		prep->name_cnt = slurm_hostlist_count(hl);
		prep->node_names = xmalloc(sizeof(char*) * prep->name_cnt);
		for (i = 0; i < prep->name_cnt && !rc; ++i) {
			if ((host = slurm_hostlist_shift(hl))) {
				prep->node_names[i] = host;
			} else {
				rc = E_HOST_LIST_SHIFT;
			}
		}
		hostlist_destroy(hl);
		return rc;
	}
	return E_HOST_LIST_CREATE;
}

static void free_nodes_names(char **node_names, int count)
{
	int i;
	char *item;
	for (i = 0; i < count; ++i) {
		item = node_names[i];
		if (item) {
			free(item);
		}
	}
	xfree(node_names);
}

/**
 * Get current job state.
 */
static void get_job_state(job_record_t *job_ptr, prep_t *prep)
{
	prep->job_state = (char *)xmalloc(10 * sizeof(char));
	if ( IS_JOB_RUNNING(job_ptr) )
		sprintf(prep->job_state, "running");
	else if ( IS_JOB_COMPLETE(job_ptr) )
		sprintf(prep->job_state, "completed");
	else if ( IS_JOB_CANCELLED(job_ptr) )
		sprintf(prep->job_state, "cancelled");
	else if ( IS_JOB_TIMEOUT(job_ptr) )
		sprintf(prep->job_state, "timeout");
	else if ( IS_JOB_OOM(job_ptr) )
		sprintf(prep->job_state, "OOM");
	else
		sprintf(prep->job_state, "failed");
}

static int get_gpu_number( job_record_t *job_ptr, prep_t *prep)
{
	int rc = SLURM_SUCCESS;
	slurm_info(P_NAME "get_gpu_number job_ptr->gres_used=%s\n", job_ptr->gres_used);

	//check gpu_alloc_cnt
	if ( job_ptr->gres_used != NULL ) {
		char *gres_alloc = strdup(job_ptr->gres_used);
		char* ptr = strtok(gres_alloc, "gpu:");
		while(ptr != NULL)
		{
			prep->gpu_alloc_cnt = atoi(ptr);
			ptr = strtok(NULL, "gpu:");
		}
		free(ptr);
		free(gres_alloc);
	}
	return rc;
}

/**
 * Print string at offset to a xmalloced string.
 * Memory will be resized as needed.
 */
static int xsnprintf_realloc(char **json, size_t offset, const char *fmt, ...)
{
	va_list args;
	size_t size = xsize(*json);
	int rc;
	va_start(args, fmt);
	rc = vsnprintf(*json + offset, size - offset, fmt, args);
	va_end(args);
	if (rc >= size - offset) {
		do {
			if (size >= SIZE_MAX / 2) {
				return E_JSON_OUT_OF_MEMORY;
			}
			size *= 2;
		} while (rc >= size - offset);
		*json = xrealloc(*json, sizeof(char) * size);
		va_start(args, fmt);
		rc = vsnprintf(*json + offset, size - offset, fmt, args);
		va_end(args);
	}
	return rc;
}

/**
 * Prepend prefix to string and xmallocs new memory with provided size.
 */
static int xprepend_prefix(char **dst, char *src, size_t size)
{
	char buffer[size];
	int rc = snprintf(buffer, size, "%s%s", prefix, src);
	*dst = xstrndup(buffer, size);
	return rc;
}

static int json_init(char **json, size_t offset, uint32_t job_id)
{
	return xsnprintf_realloc(json, offset, "{\"%"PRIu32"\":{", job_id);
}

static int
json_append_uint16(char **json, size_t offset, const char *key, uint16_t value)
{
	return xsnprintf_realloc(json, offset, "\"%s\": %"PRIu16",", key, value);
}

static int
json_append_uint32(char **json, size_t offset, const char *key, uint32_t value)
{
	return xsnprintf_realloc(json, offset, "\"%s\": %"PRIu32",", key, value);
}

static int
json_append_uint64(char **json, size_t offset, const char *key, uint64_t value)
{
	return xsnprintf_realloc(json, offset, "\"%s\": %"PRIu64",", key, value);
}

static int
json_append_uint16_array_2d(char **json, size_t offset, const char *key,
                            uint16_t **values,
                            uint16_t *value_counts,
                            uint32_t count)
{
	int i, j;
	int error = 0;
	int rc = 0;
	ADVANCE_OR_RETURN(rc, error, xsnprintf_realloc(json, offset, "\"%s\": [", key));
	for (i = 0; i < count; ++i) {
		ADVANCE_OR_RETURN(rc, error, xsnprintf_realloc(json, offset + rc, "["));
		for (j = 0; j < value_counts[i]; ++j) {
			ADVANCE_OR_RETURN(rc, error, xsnprintf_realloc(json, offset + rc, "%i,", values[i][j]));
		}
		if (j > 0) {
			(*json)[strlen(*json) - 1] = '\0';
			--rc;
		}
		ADVANCE_OR_RETURN(rc, error, xsnprintf_realloc(json, offset + rc, "],"));
	}
	if (i > 0) {
		(*json)[strlen(*json) - 1] = '\0';
		--rc;
	}
	ADVANCE_OR_RETURN(rc, error, xsnprintf_realloc(json, offset + rc, "],"));
	return rc;
}

static int
json_append_string_array(char **json, size_t offset, const char* key,
                         char **values, int count)
{
	int rc = 0, error = 0;
	int i;
	ADVANCE_OR_RETURN(rc, error, xsnprintf_realloc(json, offset, "\"%s\": [", key));
	for (i = 0; i < count; ++i) {
		ADVANCE_OR_RETURN(rc, error, xsnprintf_realloc(json, offset + rc, "\"%s\",", values[i]));
	}
	if (i > 0) {
		(*json)[offset + rc] = '\0';
		--rc;
	}
	ADVANCE_OR_RETURN(rc, error, xsnprintf_realloc(json, offset + rc, "],"));
	return rc;
}

static int
json_append_string(char **json, size_t offset, const char *key,
                   const char *value)
{
	return xsnprintf_realloc(json, offset, "\"%s\": \"%s\",", key, value);
}

static int json_append_time(char **json, size_t offset, const char *key,
                            time_t *time_ptr)
{
	char time_str[32];
	slurm_make_time_str(time_ptr, time_str, 32);
	return xsnprintf_realloc(json, offset, "\"%s\": \"%s\",", key, time_str);
}

static int json_fini(char **json, bool has_data)
{
	size_t offstet = strlen(*json);
	if (has_data) {
		(*json)[offstet - 1] = '}';
		return xsnprintf_realloc(json, offstet, "%c", '}');
	} else {
		return xsnprintf_realloc(json, offstet, "%s", "}}");
	}
}


static int
json_append_key_value_pair(char **json, size_t offset, key_value_pair_t *kvp)
{
	switch (kvp->type) {
		case U16:
			return json_append_uint16(
				json, offset, kvp->key,
				kvp->value.uint16
			);
		case U32:
			return json_append_uint32(
				json, offset, kvp->key,
				kvp->value.uint32
			);
		case U64:
			return json_append_uint64(
				json, offset, kvp->key,
				kvp->value.uint64
			);
		case CHARPP:
			return json_append_string_array(
				json, offset, kvp->key,
				kvp->value.charpp.items,
				kvp->value.charpp.count
			);
		case CHARP:
			return json_append_string(
				json, offset, kvp->key,
				kvp->value.charp
			);
		case U16PP:
			return json_append_uint16_array_2d(
				json, offset, kvp->key,
				kvp->value.uint16pp.items,
				kvp->value.uint16pp.item_counts,
				kvp->value.uint16pp.count
			);
		case TIMEP:
			return json_append_time(
				json, offset, kvp->key, kvp->value.timep
			);
		default:
			return xsnprintf_realloc(
				json, offset,
				"\"%s\":\"data type not recognised\",", kvp->key
			);
	}
}

static bool
key_required(const char *key, bool *all, bool *collect)
{
	collect[PROLOG] = all[PROLOG] || (key && !strstr(exclude_keys_prolog, key));
	collect[EPILOG] = all[EPILOG] || (key && !strstr(exclude_keys_epilog, key));
	return collect[PROLOG] || collect[EPILOG];
}

/**
 * Copy key value pairs and preped prefix to keys, which will be xmalloced or
 * nulled on error.
 * Returns SUCCESS or E_PREFIX_PREPEND;
 */
static internal_error_t
copy_key_value_pairs(key_value_pair_t *dst, key_value_pair_t *src, size_t size)
{
	int rc = SLURM_SUCCESS;
	int i;
	bool all[] = {
		strlen(exclude_keys_prolog) == 0,
		strlen(exclude_keys_epilog) == 0,
	};
	bool collect[2];
	key_value_pair_t *dst_ptr = dst;
	key_value_pair_t *src_ptr = src;
	for (i = 0; i < size && rc >= 0; ++i, ++src_ptr) {
		if (key_required(src_ptr->key, all, collect)) {
			*dst_ptr = *src_ptr;
			dst_ptr->collect[PROLOG] = collect[PROLOG];
			dst_ptr->collect[EPILOG] = collect[EPILOG];
			if (src_ptr->key) {
				dst_ptr->key = NULL;
				rc = xprepend_prefix(&(dst_ptr->key), src_ptr->key, BUFF_LEN);
			}
			++dst_ptr;
		}
	}
	return rc >= 0 ? SUCCESS : E_PREFIX_PREPEND;
}

static char _convert_dec_hex(char x)
{
	if (x <= 9)
		x += '0';
	else
		x += 'A' - 10;

	return x;
}

/* Escape characters according to RFC7159 and ECMA-262 11.8.4.2 */
static char *_json_escape(const char *str)
{
	char *ret = NULL;
	int i, o, len;

	len = strlen(str) * 2 + 128;
	ret = xmalloc(len);
	for (i = 0, o = 0; str[i]; ++i) {
		if (o >= MAX_STR_LEN) {
			break;
		} else if ((o + 8) >= len) {
			len *= 2;
			ret = xrealloc(ret, len);
		}
		switch (str[i]) {
		case '\\':
			ret[o++] = '\\';
			ret[o++] = '\\';
			break;
		case '"':
			ret[o++] = '\\';
			ret[o++] = '\"';
			break;
		case '\n':
			ret[o++] = '\\';
			ret[o++] = 'n';
			break;
		case '\b':
			ret[o++] = '\\';
			ret[o++] = 'b';
			break;
		case '\f':
			ret[o++] = '\\';
			ret[o++] = 'f';
			break;
		case '\r':
			ret[o++] = '\\';
			ret[o++] = 'r';
			break;
		case '\t':
			ret[o++] = '\\';
			ret[o++] = 't';
			break;
			break;
		case '/':
			ret[o++] = '\\';
			ret[o++] = '/';
			break;
		default:
			/* use hex for all other control characters */
			if (str[i] <= 0x1f || str[i] == '\'' || str[i] == '<' ||
			    str[i] == 0x5C) {
				ret[o++] = '\\';
				ret[o++] = 'u';
				ret[o++] = '0';
				ret[o++] = '0';
				ret[o++] =
					_convert_dec_hex((0xf0 & str[i]) >> 4);
				ret[o++] = _convert_dec_hex(0x0f & str[i]);
			} else /* normal character */
				ret[o++] = str[i];
		}
	}
	return ret;
}

static internal_error_t
job_ptr_to_json(job_record_t *job_ptr, char **json, context_t context)
{
	key_value_pair_t *kvp = collect;
	internal_error_t rc = SUCCESS;
	prep_t prep[1] = {{ .job_ptr = job_ptr }};
	int h;
	size_t max_len = BUFF_LEN;
	size_t offset = 0;
	bool has_data = false;
	buf_t *script;

	get_memory(job_ptr, prep);
	if ((rc = get_nodes_names(job_ptr, prep)) ||
	    (rc = get_cpu_ids(job_ptr, prep))) {
		return rc;
	}
	// Get user name
	prep->user = uid_to_string_or_null(job_ptr->user_id);
	// Check if multithreading is requested (this is a workaround)
	prep->smt_enabled = 0;
	if ( job_ptr->details->mc_ptr->threads_per_core == NO_VAL16 )
		prep->smt_enabled = 1;
	// Get job state
	get_job_state(job_ptr, prep);
	// Get GPU data
	if ( (rc = get_gpu_number(job_ptr, prep)) )
		return rc;

	// Escape characters according to RFC7159 and ECMA-262 11.8.4.2
	prep->job_name = _json_escape(job_ptr->name);

	script = get_job_script(job_ptr);
	if (script) {
		prep->job_script = _json_escape(get_buf_data(script));
	}

	*json = xmalloc(sizeof(char) * max_len);

	rc = json_init(json, 0, job_ptr->job_id);
	offset += rc;
	while (kvp && kvp->key && rc >= 0) {
		if (kvp->collect[context]) {
			has_data = true;
			kvp->get_value(kvp, prep);
			rc = json_append_key_value_pair(json, offset, kvp);
			if (rc >= 0) {
				offset += rc;
			}
		}
		++kvp;
	}
	if (rc >= 0) {
		rc = json_fini(json, has_data);
	}

	free_nodes_names(prep->node_names, prep->name_cnt);
	for (h = 0; h < job_ptr->job_resrcs->nhosts; ++h) {
		xfree(prep->ids[h]);
	}
	xfree(prep->ids);
	xfree(prep->id_cnts);
	xfree(prep->user);
	xfree(prep->job_state);
	xfree(prep->job_name);
	if (script)
		xfree(prep->job_script);
	free_buf(script);
	return rc >= 0 ? SUCCESS : rc;
}

static int pika_metadata_log(int job_id, char *json, bool is_epilog)
{
    FILE *fp;
    internal_error_t rc = SUCCESS;
    char file_path[100];
    sprintf(file_path, "/tmp/pika_debug/pika_prep_%d.log", job_id);
    //sprintf(file_path, "/var/log/slurm/pika.log");

    slurm_mutex_lock(&plugin_log_lock);

    fp = fopen(file_path, "a");
    if ( fp == NULL )
        return (-1);

    fprintf(fp, "----\n");

    if ( !is_epilog ) {
        fprintf(fp, "Prolog Logging of job %d\n", job_id);
    } else {
        fprintf(fp, "Epilog Logging of job %d\n", job_id);
    }

    fprintf(fp, "%s\n", json);
    xfree(json);
    fclose(fp);

    slurm_mutex_unlock(&plugin_log_lock);

    return rc >= 0 ? SUCCESS : rc;
}