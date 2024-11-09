- ### Types
> - #### [Main Categories](https://specifications.freedesktop.org/menu-spec/latest/category-registry.html#main-category-registry)
> - #### [Additional Categories](https://specifications.freedesktop.org/menu-spec/latest/additional-category-registry.html)
> - #### [Reserved Categories](https://specifications.freedesktop.org/menu-spec/latest/reserved-category-registry.html)
---

```bash
!#RAW URL
CATEGORY_URL="https://raw.githubusercontent.com/pkgforge/soarpkgs/refs/heads/main/assets/category.json"

#All categories
curl -qfsSL "${CATEGORY_URL}" | jq -r '.[] | keys[]' | sort -u

#All categories in one line
curl -qfsSL "${CATEGORY_URL}" | jq -r '.[] | keys[]' | sort -u | paste -sd ' ' -


#Only Additional Categories
curl -qfsSL "${CATEGORY_URL}" | jq -r '.Additional | keys[]'

#Only Main Categories
curl -qfsSL "${CATEGORY_URL}" | jq -r '.Main | keys[]'

#Only Reserved Categories
curl -qfsSL "${CATEGORY_URL}" | jq -r '.Reserved | keys[]'


#Get Json for a Category
curl -qfsSL "${CATEGORY_URL}" | jq '.Main.Audio'

#Get Certain Field for a category
curl -qfsSL "${CATEGORY_URL}" | jq -r '.Main.Audio.Description'

```
