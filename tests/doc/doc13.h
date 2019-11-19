#ifndef _LLIST_H_
# define _LLIST_H_

typedef int (*node_func_t)(llist_node_t node, unsigned int idx, void *arg);
typedef void (*node_dtor_t)(llist_node_t node);

/**
 * node_cmp_t - Function to compare two nodes
 *
 * @first:  Pointer to the first node
 * @second: Pointer to the second node
 * @arg:    Extra user-defined parameter
 *
 * Reurn: An integer less than, equal to, or greater than zero if first,
 *        respectively, is less than, equal, or greater than second
 */
typedef int (*node_cmp_t)(llist_node_t first, llist_node_t second, void *arg);

/**
 * node_ident_t - Function to identify a node
 *
 * @node: Pointer to the node to identify
 * @arg:  Extra user-defined parameter
 *
 * Return: Any non-zero value if @node is positively identified, 0 otherwise
 */
typedef int (*node_ident_t)(llist_node_t node, void *arg);

#endif /* ! _LLIST_H_ */
