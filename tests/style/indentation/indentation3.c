/**
 * is_perfect - check if the subtrees has the same height
 * and check for each subtree be perfect
 * @root: Tree or subtree to check
 * Return: 1 if subtree or tree is perfect or not
 */
int is_perfect(const binary_tree_t *root)
{
	if (root && _height(root->left) == _height(root->right))
	{
		if (_height(root->left) == -1)
			return (1);
		if ((root->left && !((root->left)->left)
		     && !((root->left)->right))
		    && (root->right && !((root->right)->left)
			&& !((root->right)->right)))
			return (1);
		if (root && root->left && root->right)
			return (is_perfect(root->left)
				&& is_perfect(root->right));
	}
	return (0);
}

/**
 * heap_insert - function that inserts a value in Max Binary Heap
 * @root: double pointer to the root f of the Heap to insert the value
 * @value: is the value to store in the f to be inserted
 * Return: NULL on failure
 */
heap_t *heap_insert(heap_t **root, int value)
{
	return (NULL);
}
