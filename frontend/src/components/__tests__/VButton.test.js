import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import VButton from '../VButton.vue';

describe('VButton Component', () => {
  it('renders default slot content', () => {
    const wrapper = mount(VButton, {
      slots: {
        default: 'Click Me'
      }
    });
    
    expect(wrapper.text()).toContain('Click Me');
  });

  it('emits click event when clicked', async () => {
    const wrapper = mount(VButton);
    
    await wrapper.trigger('click');
    
    expect(wrapper.emitted()).toHaveProperty('click');
    expect(wrapper.emitted('click')).toHaveLength(1);
  });

  it('is disabled when disabled prop is true', () => {
    const wrapper = mount(VButton, {
      props: {
        disabled: true
      }
    });
    
    const button = wrapper.find('button');
    expect(button.attributes('disabled')).toBeDefined();
  });
});
